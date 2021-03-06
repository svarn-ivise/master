library(shiny)
library(RMySQL)
library(httr)
library(dplyr)
library(ggplot2)
library(jsonlite)

options(shiny.trace = TRUE, shiny.sanitize.errors = FALSE)

qry2 <- function(string, ip){
  
  library(RMySQL)
  
  hst <-ip
  usr <- "shane"
  pwd <- "S13240sx91"
  dbTab <- "dynamic"
  prt <- 6603
  
  con <- dbConnect(dbDriver("MySQL"), host=hst, user=usr, password=pwd ,db= dbTab, port=prt)
  
  result<- dbGetQuery(con, paste0(string))
  
  dbDisconnect(con)
  
  all_cons <- dbListConnections(MySQL())
  for(cons in all_cons){dbDisconnect(cons)}
  
  return(result)
  
}
app2 <- function(object, table, ip){
  
  library(RMySQL)
  hst <- ip
  usr <- "shane"
  pwd <- "S13240sx91"
  dbTab <- "dynamic"
  prt <- 6603
  
  con <- dbConnect(dbDriver("MySQL"), host=hst, user=usr, password=pwd ,db= dbTab, port=prt)
  
  dbWriteTable(con, name=table, value=object, append=T, row.names=F)
  
  dbDisconnect(con)
  
  all_cons <- dbListConnections(MySQL())
  for(cons in all_cons){dbDisconnect(cons)}
  
}

spaces.key <-
spaces.secret <-
spaces.loc <- "sgp1"

#Create API node
create_api <- function(client_name){
  
  #Download API yml
  system(paste0("curl -s -LJ https://raw.githubusercontent.com/svarn-ivise/do/master/api.yml | ",
                "sed 's|spaces.key|",spaces.key,"|' | ",
                "sed 's|spaces.secret|",spaces.secret,"|' | ",
                "sed 's|spaces.loc|",spaces.loc,"|' > /tmp/api.yml"), wait=F)
  
  #Create API docker host
  # system(trimws(paste("docker-machine -D create" ,
  #                     "--driver digitalocean --digitalocean-access-token",do.tkn,
  #                     "--digitalocean-userdata /tmp/api.yml",
  #                     "--digitalocean-size s-2vcpu-4gb",
  #                     "--digitalocean-region sgp1",
  #                     "test14")), wait=F)
  
  system(paste0("docker-machine create --driver amazonec2 ",
                "--amazonec2-access-key  ",
                "--amazonec2-secret-key  ",
                "--amazonec2-userdata /tmp/api.yml ",
                "--amazonec2-instance-type 't2.medium' ",
                "--amazonec2-vpc-id vpc-32c6264a ",
                "--amazonec2-region us-west-2 ",client_name), wait=F)
  
}

#Update Model on API node
update_model <- function(){
  
  system("docker-machine ssh test13 's3cmd get --force s3://modelstorage/rf.rds /models/rf.rds'")
  system('curl -s http://128.199.154.58/updateModel')
  
}

ui <- fluidPage(
  tags$head(
    HTML('<link href="https://fonts.googleapis.com/css?family=Kodchasan" rel="stylesheet">'),
    tags$link(rel = "stylesheet", type = "text/css", href = "table.css")
  ),
  div(class='header',
    HTML("<div style='padding-top: 4px, padding-bottom:1px;'>
            <h2><b>Operations Manager</b></h2>
         </div>")),
  tabsetPanel(id = "activeTab",
    tabPanel("Client Manager", value="manage",
      column(width=1),
      column(width=11,
      fluidRow(
      br(),
      HTML('<div class="col-lg-3">
            <label>Create Client:</label>
            <div class="input-group">
              <input id="clientName" type="text" class="form-control" placeholder="Client Name">
              <span class="input-group-btn">
                <button id="createAPI"class="btn btn-secondary action-button" type="button">Create</button>
              </span>
            </div>
          </div>')),
   #  textInput("clientName","Client Name:"),
   #   actionButton("createAPI", "Create"),
      br(),
      # fileInput("file1", "Choose Model to Upload",
      #     multiple = F, 
      #     accept = c(".rds")),
     # pre(id = "console2"),
      HTML("<label>Client Machine Status:</label><br style='display:block;margin:40px 0;'>"),
      # actionButton("machList", "Go"),
      tableOutput("console3"))
    ),
    tabPanel("Client Explorer", value="explorer",
      br(),
      column(width=1),
      column(width=6,
      selectInput("selectClient","Select Client:", system("docker-machine ls --format '{{.Name}}'", inter=T)),       
      # dateInput("travel_date","Select Date",value = Sys.Date()),
      # numericInput("seats", "Select Remaining Seats", value = 100),
      # numericInput("searches", "Select Searches", value = 100),
    #  actionButton("submit", "Test"),br(),
    #  verbatimTextOutput("qryRes"),
   #   fileInput("uploadDemand", "Upload Data", accept = ".csv"),
    #  actionButton("refresh", "Refresh Table"),
      HTML("<label>Bookings:</label>"),
      DT::dataTableOutput("apiTable"))
    ),
    tabPanel("Booking Simulator", value="simulator",
             br(),
             column(width=1),
             column(width=11,
             fluidRow(
               column(width=2,
                selectInput("simClient","Select Client:", system("docker-machine ls --format '{{.Name}}'", inter=T))
               ),
               column(width=2,
                dateInput("simDate",label = "Simulation Date:",value = Sys.Date())
               ),
               column(width=2,
                      selectInput("simDays","Select Days:", c(3,6,9,12), selected=3)
               )
             ),
             fluidRow(
               column(6, plotOutput("simPlot"))#, 
          #     column(5,verbatimTextOutput("simCall"))
             ),
             fluidRow(
               column(1),
               column(3,
                sliderInput("simSamples","Select Sample Size:",min = 10, max = 100,step = 10,value=10)
               ),
               br(),br(),column(2,actionButton("simulate","Run Simulation"))
             )
    ))
  )
)

server <- function(input,output, session){
  
  obs <- reactiveValues(start = 1, obs = NULL)
  
  #Client Manager
  observeEvent(input$createAPI,{
    
    client_name <- input$clientName
    create_api(client_name)
    
  })
  observeEvent(input$file1, {
    
    inFile <- input$file1
    if (!is.null(inFile)) {
      
      model <- readRDS(inFile$datapath)
      saveRDS(model, "/tmp/rf.rds")
      system('s3cmd put --force /tmp/rf.rds s3://modelstorage/rf.rds')
      update_model()
      
    }
    
  })
  observeEvent(input$activeTab, {
    if(input$activeTab == "manage"){
      output$console3 <- renderTable({
      sys.output <- system("docker-machine ls --format '{{.Name}}##{{.URL}}##{{.State}}'", inter=T)
      sys.output <- lapply(unlist(strsplit(sys.output,split=" ")), function(x){unlist(strsplit(x,split="##"))}) %>% 
        setNames(c(1:length(.))) %>% bind_rows() %>% t() %>% 
        as.data.frame() %>% setNames(c("Name", "IP", "Status"))
      
      sys.output$IP <- gsub("tcp://|:.*", "",sys.output$IP)
      
      client_names <- sys.output$Name
      
        sys.output$Destroy <- sapply(client_names, function(client){
          as.character(actionButton(paste0("destroy_",client),"", icon=icon("remove", lib="glyphicon")))
        })
        sys.output$Call <- sapply(client_names, function(client){
          as.character(actionButton(paste0("call_",client),"", icon=icon("sort", lib="glyphicon")))
        })
        sys.output$Response <- sapply(client_names, function(client){
          as.character(verbatimTextOutput(paste0("response_",client)))
        })
      
        lapply(client_names, function (client) {
          
          if(!(client %in% obs$obs)){
            observeEvent(input[[paste0("call_",client)]], {
              
              client.ip <- gsub("tcp://|:.*", "", 
                                system(paste0("docker-machine ls -f {{.URL}} --filter name=",client), intern=T))
              
              res <- GET(paste0(client.ip,"/testModel"))
              curr.time <- as.POSIXct(format(Sys.time()),tz="Pacific/Auckland")
              
              res <- ifelse(is.numeric(fromJSON(content(res, "text"))),
                            paste0("Server is RESPONSIVE at ",curr.time),
                            paste0("Server is UNRESPONSIVE at ",curr.time))
              
              output[[paste0('response_',client)]] <- renderText({res})
            }, ignoreNULL = FALSE)
            
          }
          
            lapply(client_names, function(client){
              
                return(input[[paste0("call_",client)]])
              
            })
          
        })
        
        obs$obs <- client_names
      
      return(sys.output)
      
    }, sanitize.text.function = function(x) x)
    }
  })
  
  #Client Explorer
  observeEvent(input$activeTab,{
    if(input$activeTab == "explorer"){
      
      clients <- system("docker-machine ls --format '{{.Name}}'", inter=T)
      
      updateSelectInput(session, "selectClient",label = "Select Client:", choices=clients)
    }
  })
  output$apiTable <- DT::renderDataTable({
    input$refresh
    client.ip <- gsub("tcp://|:.*", "", 
                   system(paste0("docker-machine ls -f {{.URL}} --filter name=",input$selectClient), intern=T))
    qry2("select * from dynamic", client.ip)},
    options = list(dom = 'tp'),rownames= FALSE
    )
  observeEvent(input$submit,{
  
    travel_date <- as.character(input$travel_date)
    searches <- input$searches
    seats <- input$seats
    
    client.ip <- gsub("tcp://|:.*", "", 
                      system(paste0("docker-machine ls -f {{.URL}} --filter name=",input$selectClient), intern=T))
    
  # res <- GET("http://ec2-34-219-187-115.us-west-2.compute.amazonaws.com/dynamic",
  #     query = list(date=travel_date, seats = seats, searches=searches))
  
    res <- GET(paste0("http://",client.ip,"/testModel"))
    
  output$qryRes <- renderText(content(res, "text"))
  
  })
  observeEvent(input$uploadDemand, {
    
    client.ip <- gsub("tcp://|:.*", "", 
                      system(paste0("docker-machine ls -f {{.URL}} --filter name=",input$selectClient), intern=T))
    
    inFile <- input$uploadDemand
    if (!is.null(inFile)) {
      dmd_data <- read.csv(inFile$datapath)
      app2(dmd_data, "dynamic",client.ip)
      
    }
    
  })

  #Booking Simulator
  observeEvent(input$activeTab,{
    if(input$activeTab == "simulator"){
      
      clients <- system("docker-machine ls --format '{{.Name}}'", inter=T)
      
      updateSelectInput(session, "simClient",label = "Select Client:", choices=clients)
    }
  })
  output$simPlot <- renderPlot({  

  input$simulate
  simDate <- isolate(input$simDate)
  
  simClient <- isolate(input$simClient)
  
  client.ip <- gsub("tcp://|:.*", "", 
                    system(paste0("docker-machine ls -f {{.URL}} --filter name=",simClient), intern=T))
  
  sampleSize <- isolate(input$simSamples)
  days <- isolate(as.numeric(input$simDays))
  
    dates <- seq(simDate+1, simDate+days, by="days")
    
    res <- lapply(1:length(dates), function(i){
      lapply(1:sampleSize, function(y){
        date <- dates[i]
        load <- runif(1,0,1)
        seats <- ceiling((1-load) * 100)
        searches <- 200
        http <- paste0("http://",client.ip,"/dynamic?date=",date,"&seats=",seats,"&searches=",searches)
        output$simCall <- renderText(http)
        res <- content(GET(http))
        res <- data.frame(price = as.numeric(unlist(res$price)),
                          load = load)
      }) %>% bind_rows()
    }) %>% bind_rows() %>%
      mutate(day = rep(1:days, each=sampleSize))
  
  
  g <- res %>% ggplot(aes(x=load,y=price)) +
    geom_point() +
    facet_wrap(~day) +
    #geom_smooth(method='lm') +
    theme_bw()
  
  return(g)
  })
  
}

shinyApp(ui,server)
