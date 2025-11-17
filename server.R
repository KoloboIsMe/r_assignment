# server.R

# --- 1. PARTIE GLOBALE (s'exécute une seule fois) ---
library(shiny)
library(ggplot2)  # Pour les graphiques
library(dplyr)    # Pour la manipulation de données
library(forcats)  # Pour manipuler les "factors"
library(tidyr)    # Pour 'pivot_longer'
library(httr)     # Pour les appels API DDragon
library(jsonlite) # Pour parser le JSON DDragon
library(stringr)  # Pour 'str_split'
library(DT)       # Pour les tableaux interactifs

print("--- Démarrage de l'app : Chargement des Données et de l'API ---")

# --- 1a. Logique API DDragon (pour l'Onglet 3) ---
latest_version <- "14.13.1" # Version de fallback
item_map <- list() # Pour les tooltips des items

tryCatch({
  versions_url <- "https://ddragon.leagueoflegends.com/api/versions.json"
  versions_list <- fromJSON(rawToChar(httr::GET(versions_url)$content))
  latest_version <- versions_list[[1]]
  print(paste("Version DDragon détectée :", latest_version))
  
  items_url <- paste0("https://ddragon.leagueoflegends.com/cdn/", latest_version, "/data/en_US/item.json")
  items_json <- fromJSON(rawToChar(httr::GET(items_url)$content))
  
  item_map <- sapply(items_json$data, function(item) item$name)
  print("Données des items chargées.")
  
}, error = function(e) {
  print(paste("ERREUR API: Impossible de récupérer les données DDragon. Utilisation de la version de fallback:", latest_version))
})

# Fonctions utilitaires DDragon (pour l'Onglet 3)
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


# --- 1b. Chargement et Nettoyage des données CSV ---
tryCatch({
  data <- read.csv("faker_all_matches.csv")
  
  data_classic <- data %>%
    filter(game_mode == "CLASSIC") %>%
    mutate(
      kills = ifelse(is.na(kills), 0, kills),
      assists = ifelse(is.na(assists), 0, assists),
      deaths = ifelse(is.na(deaths), 0, deaths),
      solo_kills = ifelse(is.na(solo_kills), 0, solo_kills),
      kill_participation = ifelse(is.na(kill_participation), 0, kill_participation)
    ) %>%
    mutate(
      # 'win' est un booléen (logique TRUE/FALSE)
      deaths_adj = ifelse(deaths == 0, 1, deaths),
      kda = (kills + assists) / deaths_adj,
      duration_min = duration_sec / 60,
      lane = ifelse(lane == "NONE" | lane == "", "Inconnu", lane),
      
      # *** CORRECTION ***
      # Créer une colonne TEXTE explicite pour les couleurs/labels
      win_text = ifelse(win, "Victoire", "Défaite")
    )
  
  # --- 1c. Préparation des listes pour les filtres ---
  min_dur <- floor(min(data_classic$duration_min, na.rm = TRUE))
  max_dur <- ceiling(max(data_classic$duration_min, na.rm = TRUE))
  unique_lanes <- sort(unique(data_classic$lane))
  
  champion_list <- sort(unique(data_classic$championName))
  champion_list_tab2 <- c("Tous" = "Tous", champion_list)
  
  print("Données CSV chargées et nettoyées.")
  
}, error = function(e) {
  print("ERREUR FATALE: Impossible de charger ou de traiter 'faker_all_matches.csv'")
  print(e)
  stopApp(e) 
})


# --- 2. PARTIE SERVEUR (logique réactive) ---
shinyServer(function(input, output, session) {
  
  # --- Mise à jour des menus déroulants ---
  
  # Onglet 2
  updateSelectInput(session, "championFilter", choices = champion_list_tab2, selected = "Tous")
  updateSliderInput(session, "durationSlider", min = min_dur, max = max_dur, value = c(min_dur, max_dur))
  updateCheckboxGroupInput(session, "roleFilter", choices = unique_lanes, selected = unique_lanes)
  
  # Onglet 3
  updateSelectInput(session, "championSelect", choices = champion_list, selected = "Azir")
  
  
  # --- LOGIQUE ONGLET 1 : VUE D'ENSEMBLE (Inchangé) ---
  
  output$kdaHistogram <- renderPlot({
    ggplot(data_classic, aes(x = kda)) +
      geom_histogram(bins = 30, fill = "#007bc2", color = "white", alpha = 0.8) +
      geom_vline(aes(xintercept = median(kda, na.rm = TRUE)), color = "red", linetype = "dashed", linewidth = 1) +
      labs(title = "Distribution du KDA", x = "KDA", y = "Nombre de parties") +
      theme_minimal(base_size = 14) +
      coord_cartesian(xlim = c(0, 20))
  })
  
  output$champBarPlot <- renderPlot({
    champ_data <- data_classic %>%
      mutate(championName = fct_lump_n(championName, 10, w = NULL)) %>%
      count(championName, name = "count") %>%
      filter(championName != "Other")
    ggplot(champ_data, aes(x = reorder(championName, count), y = count, fill = championName)) +
      geom_bar(stat = "identity", show.legend = FALSE) + coord_flip() +
      labs(title = "Top 10 Champions les plus joués", x = "Champion", y = "Nombre de parties") +
      theme_minimal(base_size = 14)
  })
  
  output$roleBarPlot <- renderPlot({
    role_data <- data_classic %>% count(lane, name = "count")
    ggplot(role_data, aes(x = reorder(lane, count), y = count, fill = lane)) +
      geom_bar(stat = "identity", show.legend = FALSE) + coord_flip() +
      labs(title = "Parties par Rôle", x = "Rôle", y = "Nombre de parties") +
      theme_minimal(base_size = 14)
  })
  
  # --- LOGIQUE ONGLET 2 : ANALYSE DE PERFORMANCE (Correction) ---
  
  reactive_filtered_data <- reactive({
    req(input$durationSlider, input$roleFilter, input$championFilter)
    
    filtered_df <- data_classic %>%
      filter(
        duration_min >= input$durationSlider[1],
        duration_min <= input$durationSlider[2],
        lane %in% input$roleFilter
      )
    
    if (!("Tous" %in% input$championFilter)) {
      filtered_df <- filtered_df %>%
        filter(championName %in% input$championFilter)
    }
    
    return(filtered_df)
  })
  
  output$goldVsDamagePlot <- renderPlot({
    df <- reactive_filtered_data()
    
    # *** CORRECTION ***
    # Utiliser la colonne 'win_text' pour la couleur
    ggplot(df, aes(x = gold_earned, y = damage_dealt, color = win_text)) +
      geom_point(alpha = 0.7, size = 2) + geom_smooth(method = "lm", se = FALSE, linetype = "dashed") +
      # Mapper les couleurs aux valeurs "Victoire" et "Défaite"
      scale_color_manual(name = "Résultat", 
                         values = c("Victoire" = "#007bc2", "Défaite" = "#d9534f")) +
      labs(x = "Or Gagné", y = "Dégâts Totaux Infligés") + theme_minimal(base_size = 14)
  })
  
  output$victoryFactorsPlot <- renderPlot({
    df <- reactive_filtered_data()
    df_pivoted <- df %>%
      # *** CORRECTION *** (utiliser win_text)
      select(win_text, "Part. Kills" = kill_participation, "Solo Kills" = solo_kills, "Dégâts Bâtiments" = damage_dealt_to_buildings, "KDA" = kda) %>%
      pivot_longer(cols = -win_text, names_to = "stat_type", values_to = "value")
    
    # *** CORRECTION ***
    ggplot(df_pivoted, aes(x = win_text, y = value, fill = win_text)) +
      geom_boxplot() + facet_wrap(~ stat_type, scales = "free_y") + 
      # Mapper les couleurs de remplissage
      scale_fill_manual(name = "Résultat", 
                        values = c("Victoire" = "#007bc2", "Défaite" = "#d9534f")) +
      labs(x = "", y = "Valeur") + theme_minimal(base_size = 14) + theme(legend.position = "none") 
  })
  
  output$scalingPlot <- renderPlot({
    df <- reactive_filtered_data()
    
    # *** CORRECTION ***
    # Utiliser la colonne 'win_text' pour la couleur
    ggplot(df, aes(x = duration_min, y = minions_killed, color = win_text)) +
      geom_point(alpha = 0.5) + geom_smooth(method = "lm", se = FALSE) +
      # Mapper les couleurs
      scale_color_manual(name = "Résultat", 
                         values = c("Victoire" = "#007bc2", "Défaite" = "#d9534f")) +
      labs(x = "Durée (minutes)", y = "Sbires Tués (CS)") + theme_minimal(base_size = 14)
  })
  
  
  # --- LOGIQUE ONGLET 3 : HISTORIQUE VISUEL (Inchangé) ---
  
  output$matchHistoryTitle <- renderText({
    paste("Historique des matchs pour :", input$championSelect)
  })
  
  output$matchHistoryTable <- DT::renderDT({
    req(input$championSelect)
    
    champ_data <- data_classic %>%
      filter(championName == input$championSelect) %>%
      select(win, kills, deaths, assists, kda, minions_killed, gold_earned, items) 
    
    items_html <- sapply(champ_data$items, function(items_string) {
      item_ids <- str_split(items_string, ";")[[1]]
      
      img_tags <- sapply(item_ids, function(id) {
        if (id != "0" && !is.na(id) && id != "") {
          item_name <- ifelse(id %in% names(item_map), item_map[[id]], "Item")
          as.character(tags$img(
            src = get_item_img_url(id), 
            height = "30px", 
            style = "margin: 1px; border-radius: 5px;",
            title = item_name
          ))
        } else {
          "" 
        }
      })
      paste(img_tags, collapse = "")
    })
    
    display_data <- champ_data %>%
      mutate(
        Items = items_html,
        KDA = paste(kills, deaths, assists, sep = "/"),
        # 'win' est un booléen, 'ifelse' fonctionne
        Victoire = ifelse(win, 
                          "<span style='color:green; font-weight:bold;'>Victoire</span>", 
                          "<span style='color:red;'>Défaite</span>")
      ) %>%
      select(Victoire, KDA, "CS" = minions_killed, "Gold" = gold_earned, Items)
    
    datatable(
      display_data,
      escape = FALSE,
      rownames = FALSE,
      options = list(
        pageLength = 10,
        autoWidth = FALSE,
        columnDefs = list(
          list(width = '80px', targets = c(0, 1, 2, 3)), 
          list(width = '250px', targets = 4) # Items
        )
      )
    )
  })
}) # Fin de shinyServer