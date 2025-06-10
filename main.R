# Clear all objects
rm(list = ls())

# change to TRUE to unzip the output file
unzip = FALSE 

# import functions needed to run API
source("functions-api-combined.R")

# Grab login variables from file (see readme for details)
source(".env-demo")
username = COGNITO_USER_NAME
password = COGNITO_PASSWORD
client_id = COGNITO_CLIENT_ID
region = COGNITO_REGION
api_url = APLOS_API_URL

# here are some default file and config setups.
# adjust your code accordingly
input_file = "./files/single_ev.csv"
config_file = "./files/configuration_single_ev.json"
#meta_file = ""
meta_file = "./files/meta_data.json"
#data_processing_file = ""
data_processing_file = "./files/data_processing.json"
#post_processing_file = ""
post_processing_file = "./files/post_processing.json"

# Authenticate user for access to API
cat("Log in ... \n")
current.jwt <- get_jwt(client_id,username,password,region)

# Record the start time for the script
start_time <- Sys.time()

# Run the analysis
aplos_nca(api_url,current.jwt,input_file,config_file,meta_file,data_processing_file,post_processing_file,unzip)

# Record the end time for the script
end_time <- Sys.time()
total_time <- hms_span(start_time,end_time)
cat(paste0("Total runtime was ",total_time," (Hours:Minutes:Seconds) \n"))
