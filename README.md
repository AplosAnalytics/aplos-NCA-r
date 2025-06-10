These scripts can be used to facilitate use of the Aplos NCA API through R.
Packages are provided as-is with no warranty.
Current detailed information on the Aplos NCA API is available at https://docs.aplosanalytics.com and at https://aplosanalytics.com

## Format of .env file for password
The .env file is a hidden file used to store the username/password combination for access to the API. It is not recommended to store this information in a public repository, thus the hidden files should be excluded from any repositories that you create. All of the required information (except username and password) are available from the web interface under API Sesttings. The file should be a text file with the following format:

APLOS_API_URL="https://[your.url]"  
COGNITO_CLIENT_ID="[your cognito client id]"  
COGNITO_USER_NAME="[your username (email address)]"  
COGNITO_PASSWORD="[your password]"  
COGNITO_REGION="[your cognito region]"  


