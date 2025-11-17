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
    
    # --- (NOUVEAU) ONGLET 1 : ACCUEIL ---
    tabPanel(
      "Accueil",
      icon = icon("home"),
      fluidPage(
        titlePanel("Bienvenue sur l'Analyseur de Matchs de Faker"),
        hr(),
        
        fluidRow(
          column(width = 8,
                 h3("Qui est Faker ?"),
                 p("Lee Sang-hyeok (이상혁), mondialement connu sous le pseudonyme de **Faker**, est un joueur professionnel sud-coréen de League of Legends. Il est largement considéré comme le meilleur joueur de tous les temps, ce qui lui vaut le surnom de « Roi Démon Imbattable » (Unkillable Demon King)."),
                 p("Il joue au poste de *Midlaner* pour l'équipe **T1** (anciennement SK Telecom T1), une organisation qu'il n'a jamais quittée depuis ses débuts en 2013. En février 2020, il est également devenu copropriétaire de T1 Entertainment & Sports."),
                 
                 h3("Un Palmarès Inégalé"),
                 p("La longévité et la domination de Faker sont sans précédent dans l'histoire de l'esport. À ce jour, son palmarès principal inclut :"),
                 tags$ul(
                   tags$li(HTML("<b>6 fois Champion du Monde</b> de League of Legends (2013, 2015, 2016, 2023, 2024, 2025)")),
                   tags$li(HTML("<b>2 fois Vainqueur du Mid-Season Invitational (MSI)</b> (2016, 2017)")),
                   tags$li(HTML("<b>10 fois Champion de Corée (LCK)</b>")),
                   tags$li(HTML("<b>Vainqueur de l'Esports World Cup</b> (2024)")),
                   tags$li(HTML("<b>Médaille d'or</b> aux Jeux Asiatiques (2022)"))
                 ),
                 
                 h3("À Propos de cette Application"),
                 p("Cette application Shiny a été conçue pour explorer et visualiser les données d'un historique de matchs (fictif) de Faker."),
                 p("L'objectif est d'utiliser la puissance de R, `ggplot2` et des outils interactifs pour analyser ses performances à travers différents angles :"),
                 tags$ul(
                   tags$li(HTML("<b>Vue d'ensemble :</b> Découvrez ses champions et rôles les plus joués, ainsi que la distribution de son KDA.")),
                   tags$li(HTML("<b>Analyse de Performance :</b> Plongez dans les graphiques interactifs pour voir la corrélation entre son or, ses dégâts, ses CS et les conditions de victoire, en filtrant par champion ou durée de partie.")),
                   tags$li(HTML("<b>Historique Visuel :</b> Explorez les matchs d'un champion spécifique et visualisez les builds d'items utilisés grâce à l'intégration de l'API DDragon de Riot Games."))
                 )
          ),
          
          column(width = 4,
                 # 
                 tags$img(src = "https://www.redbull.com/images/c_limit,w_1500,h_1000,f_auto,q_auto/redbullcom/2022/10/12/fpg03i2y28g544mrcg6s/faker-t1-worlds-2022",
                          style = "width: 100%; border-radius: 10px;"),
                 hr(),
                 # 
                 tags$img(src = "https://upload.wikimedia.org/wikipedia/en/thumb/5/5d/T1_%28esports%29_logo.svg/1200px-T1_%28esports%29_logo.svg.png",
                          style = "width: 100%;")
          )
        )
      )
    ),
    
    # --- ONGLET 2 : VUE D'ENSEMBLE (Anciennement Onglet 1) ---
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
    
    # --- ONGLET 3 : ANALYSE DE PERFORMANCE (Anciennement Onglet 2) ---
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
    
    # --- ONGLET 4 : HISTORIQUE VISUEL (Anciennement Onglet 3) ---
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
          )
        ),
        mainPanel(
          width = 9,
          h3(textOutput("matchHistoryTitle")),
          DT::DTOutput("matchHistoryTable")
        )
      )
    )
  ) # Fin de navbarPage
) # Fin de shinyUI