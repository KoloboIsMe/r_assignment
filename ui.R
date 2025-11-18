# ui.R

# --- 1. CHARGEMENT DES LIBRAIRIES ---
library(shiny)
library(shinythemes) # Pour les thèmes
library(ggplot2)     # Moteur de graphiques
library(DT)          # Pour les tableaux interactifs

# --- 2. DÉFINITION DE L'INTERFACE ---
shinyUI(
  
  # Utilise navbarPage pour créer une barre de navigation avec des onglets
  navbarPage(
    title = "Analyse Visuelle - Faker",
    theme = shinythemes::shinytheme("flatly"), 
    
    # --- ONGLET 1 : ACCUEIL ---
    tabPanel(
      "Accueil",
      icon = icon("home"),
      fluidPage(
        titlePanel("Bienvenue sur l'Analyseur de Matchs de Faker"),
        hr(),
        fluidRow(
          column(width = 8,
                 h3("Qui est Faker ?"),
                 p("Lee Sang-hyeok (이상혁), mondialement connu sous le pseudonyme de Faker, est un joueur professionnel sud-coréen de League of Legends."),
                 p("Il joue au poste de Midlaner pour l'équipe T1. Surnommé \"The Unkillable DemonKing\", il est considéré comme le meilleur joueur de l'histoire du jeu, et de l'esport en général."),
                 h3("Un Palmarès Inégalé"),
                 tags$ul(
                   tags$li(HTML("<b>Champion du Monde</b> 6 fois, avec des équipes différentes")),
                   tags$li(HTML("<b>Champion MSI</b>")),
                   tags$li(HTML("<b>Champion de la Ligue Coréenne</b> (10+ titres)"))
                 ),
                 h3("À Propos de cette Application"),
                 p("Explorez les données de jeu de Faker : KDA, Gold, Dégâts et builds d'items."),
                 p("Le but étant d'analyser ses stats pour définir comment il joue, ses critères de victoire..."),
                 h3("Pages"),
                 tags$ul(
                   tags$li(HTML("<b>Page 1</b> : statistiques générales.")),
                   tags$li(HTML("<b>Page 2</b> : analyse en profondeur des critères qui font que Faker gagne. (or, dégats, KDA, ...)")),
                   tags$li(HTML("<b>Page 3</b> : Vues globales de ses parties triées par champion, pour une meilleure vue d'ensemble."))
                 ),
          ),
          column(width = 4,
                 tags$img(src = "https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/Faker_2020_interview.jpg/640px-Faker_2020_interview.jpg",
                          style = "width: 100%; border-radius: 10px;")
          )
        )
      )
    ),
    
    # --- ONGLET 2 : VUE D'ENSEMBLE ---
    tabPanel(
      "Vue d'ensemble",
      icon = icon("chart-pie"),
      fluidPage(
        titlePanel("Statistiques Globales (Mode 'CLASSIC')"),
        hr(),
        fluidRow(column(width = 12, plotOutput("kdaHistogram", height = "300px"))),
        hr(),
        fluidRow(
          column(width = 6, plotOutput("champBarPlot", height = "400px")),
          column(width = 6, plotOutput("roleBarPlot", height = "400px"))
        )
      )
    ),
    
    # --- ONGLET 3 : ANALYSE DE PERFORMANCE ---
    tabPanel(
      "Analyse de Performance",
      icon = icon("search-dollar"),
      sidebarLayout(
        sidebarPanel(
          width = 3,
          h4("Filtres de Performance"),
          
          selectInput(
            "championFilter",
            "Filtrer par Champion :",
            choices = NULL, 
            multiple = TRUE, 
            selected = "Tous"
          ),
          sliderInput(
            "durationSlider",
            "Filtrer par Durée (minutes) :",
            min = 0, max = 60, value = c(0, 60)
          ),
          checkboxGroupInput(
            "roleFilter",
            "Filtrer par Rôle :",
            choices = NULL, 
            selected = NULL
          )
        ),
        mainPanel(
          width = 9,
          h4("1. Le Moteur Économique : Or vs Dégâts"),
          plotOutput("goldVsDamagePlot", height = "400px"),
          hr(),
          h4("2. Les Facteurs de Victoire : Stats Clés (Victoire vs Défaite)"),
          plotOutput("victoryFactorsPlot", height = "400px"),
          hr(),
          h4("3. La Montée en Puissance : CS vs Durée"),
          plotOutput("scalingPlot", height = "400px")
        )
      )
    ),
    
    # --- ONGLET 4 : HISTORIQUE VISUEL ---
    tabPanel(
      "Historique Visuel des Matchs",
      icon = icon("dragon"),
      sidebarLayout(
        sidebarPanel(
          width = 3,
          
          selectInput(
            "championSelect",
            "Choisir un champion :",
            choices = NULL
          ),
          
          hr(),
          
          # *** NOUVEAU : Zone pour les stats récapitulatives ***
          uiOutput("champStatsCard")
        ),
        mainPanel(
          width = 9,
          h3(textOutput("matchHistoryTitle")),
          DT::DTOutput("matchHistoryTable")
        )
      )
    )
  ) # Fin navbarPage
) # Fin shinyUI