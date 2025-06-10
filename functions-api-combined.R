# R Functions for Aplos API
suppressPackageStartupMessages(library(httr))
suppressPackageStartupMessages(library(jsonlite))
suppressPackageStartupMessages(library(downloader))
suppressPackageStartupMessages(library(stringr))
suppressPackageStartupMessages(library(AzureAuth))

hms_span <- function(start, end) {
  dsec <- as.numeric(difftime(end, start, unit = "secs"))
  hours <- floor(dsec / 3600)
  minutes <- floor((dsec - 3600 * hours) / 60)
  seconds <- dsec - 3600*hours - 60*minutes
  paste0(
    sapply(c(hours, minutes, seconds), function(x) {
      formatC(x, width = 2, format = "d", flag = "0")
    }), collapse = ":")
}

get_jwt <- function(client_id, username, password, region){
  headers <- c("Content-Type" = "application/x-amz-json-1.1", 
               "X-Amz-Target" = "AWSCognitoIdentityProviderService.InitiateAuth")
  body <- list(
    AuthFlow="USER_PASSWORD_AUTH",
    AuthParameters=list("USERNAME"=username, "PASSWORD"=password),
    ClientId=client_id,
    method_type = "post"
  )
  
  response <- POST(url = paste0("https://cognito-idp.",region,".amazonaws.com/"),
                   add_headers(.headers = headers),
                   body = toJSON(body, auto_unbox = TRUE))
  
  result <- fromJSON(content(response, "text", encoding = "UTF-8"))
  jwt <- result$AuthenticationResult$IdToken
  return(jwt)
}

get_upload_url <- function(input_file,url,token){
  # url = api_url
  # token = current.jwt
  tenant_id <- decode_jwt(token)$payload$`custom:aplos_user_tenant_id`
  user_id <- decode_jwt(token)$payload$`custom:aplos_user_id`
  filename = str_split_i(input_file, "/", -1)
  upload_url = paste0(url,"/tenants/",tenant_id,"/users/",user_id,"/nca/files")
  headers <- c("Content-Type" = "application/json",
               "Authorization" = paste0("Bearer ",token))
  body <- list(
    "file_name"=filename,
    method_type = "post"
  )
  
  response <- POST(url = upload_url,
                   add_headers(.headers = headers),
                   body = toJSON(body, auto_unbox = TRUE))
  
  result <- fromJSON(content(response, "text", encoding = "UTF-8"))
  return(result)
}

upload_file_api <- function(input_file,result){
  upload_url = result$presigned$url
  headers <- c()
  body <- list(
    key = result$presigned$fields$key,
    "x-amz-algorithm" = result$presigned$fields$`x-amz-algorithm`,
    "x-amz-credential" = result$presigned$fields$`x-amz-credential`,
    "x-amz-date" = result$presigned$fields$`x-amz-date`,
    "x-amz-security-token" = result$presigned$fields$`x-amz-security-token`,
    policy = result$presigned$fields$policy,
    "x-amz-signature" = result$presigned$fields$`x-amz-signature`,
    file = upload_file(normalizePath(input_file))
  )
  
  response <- POST(url = upload_url, body = body)
  
}

execute_analysis <- function(result,token,url,config = "{}", meta = "{}",
                             data.processing = "{}", post.processing = "{}"){
  # token = current.jwt
  # config = config
  # meta = meta
  # url = api_url
  # result = upload_result
  # data.processing = data.processing
  # post.processing = post.processing
  tenant_id <- decode_jwt(token)$payload$`custom:aplos_user_tenant_id`
  user_id <- decode_jwt(token)$payload$`custom:aplos_user_id`
  headers <- c("Content-Type" = "application/json",
               "Authorization" = paste0("Bearer ",token))
  json_payload <- paste0("{\n",
                 '    "file": { \n  "id": "',result$file$id,'" \n}',
                 ',\n    "configuration": ', config,
                 ',\n    "meta": ', meta,
                 ',\n    "data_processing": ', data.processing,
                 ',\n    "post_processing": ', post.processing,
                 "\n}")
 
  response <- POST(url = paste0(url,"/tenants/",tenant_id,"/users/",user_id,"/nca/executions"),
                   add_headers(.headers = headers),
                   body = json_payload, encode = "raw")

  # Check the response
  # print(content(response,"text"))
  if (http_status(response)$category == "Success") {
    cat("Execution initiated. \n")
  } else {
    cat("Error in the request. \n")
  }
  
  result <- fromJSON(content(response, "text", encoding = "UTF-8"))
  execution_id <- result$execution_id
  return(execution_id)
}

execution_status <- function(url,token,execution_id){
  # execution_id = exec_id
  # url = api_url
  # token = current.jwt
  tenant_id <- decode_jwt(token)$payload$`custom:aplos_user_tenant_id`
  user_id <- decode_jwt(token)$payload$`custom:aplos_user_id`
  headers <- c("Content-Type" = "application/json",
               "Authorization" = paste0("Bearer ",token))
  complete <- FALSE
  while (!complete) {
    response <- GET(paste0(url,"/tenants/",tenant_id,"/users/",user_id,"/nca/executions/",execution_id),
                    add_headers(.headers = headers))
    result <- fromJSON(content(response, "text", encoding = "UTF-8"))
    if(result$status == "failed") {break}
    complete <- result$status == "complete"
    if(!complete) {
      cat(paste0("Not yet complete ... ",result$status," \n"))
      Sys.sleep(4)}
  }
  
  if(result$status == "complete") {
    cat("Execution complete. \n")
    #cat(paste0("Execution duration = ",result$elapsed,". \n"))
    return(result)
  } else {
    cat(paste0("Execution failed. Execution ID = ",execution_id,"\n"))
  }
  
  
}

aplos_nca <- function(api_url,current.jwt,input_file,config_file,meta_file,
                      data_processing_file,post_processing_file,unzip){
  cat("Welcome to the NCA Engine Upload & Execution \n")
  
  cat("Uploading input file ... \n")
  upload_result <- get_upload_url(input_file = input_file, url = api_url, token = current.jwt)
  upload_file_api(input_file = input_file, result = upload_result)
  
  cat("Loading analysis configurations \n")
  config <- paste(readLines(config_file, warn = FALSE), collapse = "\n")
  
  cat("Loading analysis meta data \n")
  if(meta_file != "") {
    meta <- paste(readLines(meta_file, warn = FALSE), collapse = "\n")
  } else {
    meta <- "{}"
  }
  
  cat("Loading data processing json file \n")
  if(data_processing_file != "") {
    data.processing <- paste(readLines(data_processing_file, warn = FALSE), collapse = "\n")
  } else {
    data.processing <- "{}"
  }
  
  
  cat("Loading post processing json file \n")
  if(post_processing_file != "") {
    post.processing <- paste(readLines(post_processing_file, warn = FALSE), collapse = "\n")
  } else {
    post.processing <- "{}"
  }
  
  cat("Initiating analysis ... \n")
  exec_id <- execute_analysis(result = upload_result, token = current.jwt, url = api_url, 
                              config = config, meta = meta, 
                              data.processing = data.processing,
                              post.processing = post.processing)

  cat("Checking status \n")
  exec_result <- execution_status(url = api_url, token = current.jwt, execution_id = exec_id)
  
  # Download completed analysis files
  if(exec_result$status == "complete") {
    download_url <- exec_result$presigned$url
    output_file <- paste0("output/output-",format(Sys.time(),"%Y-%m-%d-%Hh%Mm%Ss"),".zip")
    # create output directory if doesn't already exist
    if (!dir.exists("output")) {dir.create("output")}
    download(download_url, dest=output_file, mode = "wb", quiet = TRUE)
    if(unzip) {
      unzip(output_file, exdir = "output/unzip")
      cat("Results file downloaded and unziped. \n")
      cat(paste0("Location is output/unzip \n"))
    } else {
      cat("Results file downloaded. \n")
    }
    
  }

}
