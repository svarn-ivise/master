library(shiny)

do.tkn <- 
spaces.key <- 
spaces.secret <- 
spaces.loc <- "sgp1"
db.ip <- 


#Create Client
create_client <- function(){

#Download API yml
system(paste0("curl -LJO http://www.google.com https://raw.githubusercontent.com/svarn-ivise/do/master/api.yml |
                sed 's|spaces.key|",spaces.key," |' |
                sed 's|spaces.secret|",spaces.secret,"|' |
                sed 's|spaces.loc|",spaces.loc,"|' |
                sed 's|db.ip|",db.ip,"|' > /tmp/api.yml"))
  
#Create API
system(trimws(paste("docker-machine create" ,
              "--engine-install-url=https://web.archive.org/web/20170623081500/https://get.docker.com",
              "--driver digitalocean --digitalocean-access-token",do.tkn,
              "--digitalocean-userdata /tmp/api.yml",
              "--digitalocean-size s-2vcpu-4gb",
              "--digitalocean-region sgp1",
              "--digitalocean-image docker-18-04",
             "test12")), wait=F)
  
}
