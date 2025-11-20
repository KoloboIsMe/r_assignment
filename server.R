# server.R

# --- 1. PARTIE GLOBALE ---
library(shiny)
library(ggplot2)
library(dplyr)
library(forcats)
library(tidyr)
library(httr)
library(jsonlite)
library(stringr)
library(DT)

print("--- Démarrage de l'app : Chargement des Données et de l'API ---")

# --- 1a. Logique API DDragon ---
latest_version <- "14.13.1" 
item_map <- list() 

tryCatch({
  versions_url <- "https://ddragon.leagueoflegends.com/api/versions.json"
  versions_list <- fromJSON(rawToChar(httr::GET(versions_url)$content))
  latest_version <- versions_list[[1]]
  
  items_url <- paste0("https://ddragon.leagueoflegends.com/cdn/", latest_version, "/data/en_US/item.json")
  items_json <- fromJSON(rawToChar(httr::GET(items_url)$content))
  item_map <- sapply(items_json$data, function(item) item$name)
  
}, error = function(e) {
  print(paste("ERREUR API DDragon (utilisation version fallback):", latest_version))
})

get_item_img_url <- function(item_id) {
  item_id_str <- as.character(item_id)
  if (item_id_str == "0" || is.na(item_id) || item_id_str == "") {
    return("data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==")
  }
  paste0("https://ddragon.leagueoflegends.com/cdn/", latest_version, "/img/item/", item_id_str, ".png")
}

get_champ_img_url <- function(champion_name) {
  paste0("https://ddragon.leagueoflegends.com/cdn/", latest_version, "/img/champion/", champion_name, ".png")
}

# --- 1b. Chargement CSV ---
tryCatch({
  data <- read.csv("faker_all_matches.csv")
  
  data_classic <- data |>
    filter(game_mode == "CLASSIC") |>
    mutate(
      kills = ifelse(is.na(kills), 0, kills),
      assists = ifelse(is.na(assists), 0, assists),
      deaths = ifelse(is.na(deaths), 0, deaths),
      solo_kills = ifelse(is.na(solo_kills), 0, solo_kills),
      kill_participation = ifelse(is.na(kill_participation), 0, kill_participation)
    ) |>
    mutate(
      # *** CORRECTION ROBUSTE ***
      # Convertit en texte minuscule, puis compare à "true".
      # Fonctionne que ce soit un booléen (TRUE) ou du texte ("True"/"true").
      win = (tolower(as.character(win)) == "true"),
      
      deaths_adj = ifelse(deaths == 0, 1, deaths),
      kda = (kills + assists) / deaths_adj,
      duration_min = duration_sec / 60,
      lane = ifelse(lane == "NONE" | lane == "", "Inconnu", lane),
      win_text = ifelse(win, "Victoire", "Défaite")
    )
  
  min_dur <- floor(min(data_classic$duration_min, na.rm = TRUE))
  max_dur <- ceiling(max(data_classic$duration_min, na.rm = TRUE))
  unique_lanes <- sort(unique(data_classic$lane))
  champion_list <- sort(unique(data_classic$championName))
  champion_list_tab2 <- c("Tous" = "Tous", champion_list)
  
}, error = function(e) {
  stopApp(e) 
})


# --- 2. PARTIE SERVEUR ---
shinyServer(function(input, output, session) {
  
  # Mise à jour des inputs
  updateSelectInput(session, "championFilter", choices = champion_list_tab2, selected = "Tous")
  updateSliderInput(session, "durationSlider", min = min_dur, max = max_dur, value = c(min_dur, max_dur))
  updateCheckboxGroupInput(session, "roleFilter", choices = unique_lanes, selected = unique_lanes)
  updateSelectInput(session, "championSelect", choices = champion_list, selected = "Azir")
  
  
  # --- ONGLET 2 : VUE D'ENSEMBLE ---
  output$kdaHistogram <- renderPlot({
    ggplot(data_classic, aes(x = kda)) +
      geom_histogram(bins = 30, fill = "#007bc2", color = "white", alpha = 0.8) +
      geom_vline(aes(xintercept = median(kda, na.rm = TRUE)), color = "red", linetype = "dashed") +
      labs(title = "Distribution du KDA", x = "KDA", y = "Parties") + theme_minimal()
  })
  
  output$champBarPlot <- renderPlot({
    champ_data <- data_classic |>
      mutate(championName = fct_lump_n(championName, 10, w = NULL)) |>
      count(championName, name = "count") |> filter(championName != "Other")
    ggplot(champ_data, aes(x = reorder(championName, count), y = count, fill = championName)) +
      geom_bar(stat = "identity", show.legend = FALSE) + coord_flip() +
      labs(title = "Top 10 Champions", x = "Champion", y = "Parties") + theme_minimal()
  })
  
  output$roleBarPlot <- renderPlot({
    role_data <- data_classic |> count(lane, name = "count")
    ggplot(role_data, aes(x = reorder(lane, count), y = count, fill = lane)) +
      geom_bar(stat = "identity", show.legend = FALSE) + coord_flip() +
      labs(title = "Parties par Rôle", x = "Rôle", y = "Parties") + theme_minimal()
  })
  
  # --- ONGLET 3 : PERFORMANCE ---
  reactive_filtered_data <- reactive({
    req(input$durationSlider, input$roleFilter, input$championFilter)
    df <- data_classic |> filter(duration_min >= input$durationSlider[1], duration_min <= input$durationSlider[2], lane %in% input$roleFilter)
    if (!("Tous" %in% input$championFilter)) { df <- df |> filter(championName %in% input$championFilter) }
    return(df)
  })
  
  output$goldVsDamagePlot <- renderPlot({
    ggplot(reactive_filtered_data(), aes(x = gold_earned, y = damage_dealt, color = win_text)) +
      geom_point(alpha = 0.7, size = 2) + geom_smooth(method = "lm", se = FALSE, linetype = "dashed") +
      scale_color_manual(name = "Résultat", values = c("Victoire" = "#007bc2", "Défaite" = "#d9534f")) +
      labs(x = "Or Gagné", y = "Dégâts Totaux") + theme_minimal()
  })
  
  output$victoryFactorsPlot <- renderPlot({
    df_pivoted <- reactive_filtered_data() |>
      select(win_text, "Part. Kills" = kill_participation, "Solo Kills" = solo_kills, "CS Total" = minions_killed, "KDA" = kda) |>
      pivot_longer(cols = -win_text, names_to = "stat_type", values_to = "value")
    
    ggplot(df_pivoted, aes(x = win_text, y = value, fill = win_text)) +
      geom_boxplot() + facet_wrap(~ stat_type, scales = "free_y") + 
      scale_fill_manual(name = "Résultat", values = c("Victoire" = "#007bc2", "Défaite" = "#d9534f")) +
      labs(x = "", y = "Valeur") + theme_minimal() + theme(legend.position = "none") 
  })
  
  output$scalingPlot <- renderPlot({
    ggplot(reactive_filtered_data(), aes(x = duration_min, y = minions_killed, color = win_text)) +
      geom_point(alpha = 0.5) + geom_smooth(method = "lm", se = FALSE) +
      scale_color_manual(name = "Résultat", values = c("Victoire" = "#007bc2", "Défaite" = "#d9534f")) +
      labs(x = "Durée (min)", y = "CS") + theme_minimal()
  })
  
  # --- ONGLET 4 : HISTORIQUE & STATS ---
  
  reactive_champ_data <- reactive({
    req(input$championSelect)
    data_classic |> filter(championName == input$championSelect)
  })
  
  output$matchHistoryTitle <- renderText({
    paste("Historique des matchs pour :", input$championSelect)
  })
  
  output$champStatsCard <- renderUI({
    df <- reactive_champ_data()
    
    # Calculs des moyennes
    n_games <- nrow(df)
    
    # *** CORRECTION ICI *** # na.rm = TRUE évite le "NA%"
    win_rate <- round(mean(df$win, na.rm = TRUE) * 100, 1)
    
    avg_kda <- round(mean(df$kda, na.rm = TRUE), 2)
    avg_cs_min <- round(mean(df$minions_killed / df$duration_min, na.rm = TRUE), 1)
    
    champ_img <- get_champ_img_url(input$championSelect)
    
    tagList(
      div(style = "text-align: center;",
          tags$img(src = champ_img, width = "100px", style = "border-radius: 50%; margin-bottom: 10px; border: 3px solid #2c3e50;"),
          h3(input$championSelect, style = "margin-top: 0;")
      ),
      br(),
      div(style = "background-color: #ecf0f1; padding: 15px; border-radius: 5px;",
          h5(strong("Parties Jouées :"), n_games),
          h5(strong("Winrate :"), 
             span(paste0(win_rate, "%"), style = ifelse(win_rate >= 50, "color: green;", "color: red;"))),
          h5(strong("KDA Moyen :"), avg_kda),
          h5(strong("CS / Minute :"), avg_cs_min)
      )
    )
  })
  
  output$matchHistoryTable <- DT::renderDT({
    champ_data <- reactive_champ_data() |>
      select(win, kills, deaths, assists, kda, minions_killed, gold_earned, items) 
    
    items_html <- sapply(champ_data$items, function(items_string) {
      item_ids <- str_split(items_string, ";")[[1]]
      img_tags <- sapply(item_ids, function(id) {
        if (id != "0" && !is.na(id) && id != "") {
          item_name <- ifelse(id %in% names(item_map), item_map[[id]], "Item")
          as.character(tags$img(src = get_item_img_url(id), height = "30px", style = "margin: 1px; border-radius: 4px;", title = item_name))
        } else { "" }
      })
      paste(img_tags, collapse = "")
    })
    
    display_data <- champ_data |>
      mutate(
        Items = items_html,
        KDA = paste(kills, deaths, assists, sep = "/"),
        Victoire = ifelse(win, "<span style='color:green; font-weight:bold;'>Victoire</span>", "<span style='color:red;'>Défaite</span>")
      ) |>
      select(Victoire, KDA, "CS" = minions_killed, "Gold" = gold_earned, Items)
    
    datatable(display_data, escape = FALSE, rownames = FALSE, 
              options = list(pageLength = 10, autoWidth = FALSE, 
                             columnDefs = list(list(width = '80px', targets = c(0, 1, 2, 3)), list(width = '250px', targets = 4))))
  })
})
