library(lubridate)
library(dplyr)
library(scales)
library(RODBC)
library(RCurl)
library(httr)
library(jsonlite)


instance <- 'https://###-XXX-###.mktorest.com/'

# Authentication ----------------------------------------------------------
#http://developers.marketo.com/documentation/rest/authentication/

authentication_url <- AUTH_URL_HERE
auth_r <- GET(authentication_url)
str(content(auth_r))
token <- content(auth_r)$access_token
(marketo_access_token <- paste0('?access_token=',token))

# Get Paging Token --------------------------------------------------------
# http://developers.marketo.com/documentation/rest/get-paging-token
# This API returns a token for a given date. The paging token represents a cursor in the database. 
# This token is used with Get Lead Activities or Get Lead Changes, 
# and you must first call this API before call the Get Lead Activities or Get Lead Changes APIs.

paging_token_endpoint <- "/rest/v1/activities/pagingtoken.json"
since_date_time = "&sinceDatetime=2015-06-01T00:00:00-00:00"
paging_token_url <- paste0(instance, paging_token_endpoint, marketo_access_token, since_date_time)

paging_token_r <- GET(paging_token_url)
headers(paging_token_r)

str(content(paging_token_r))

paging_token <- content(paging_token_r)[[3]]


# Get Activity Types ------------------------------------------------------
# http://developers.marketo.com/documentation/rest/get-activity-types/

# Descriptions:
#This API returns meta data about activity types (except change data value) available in Marketo. 
# For example, activity types include form fill, web page visit, or lead creation. With the id for the specific activity type, 
# you can query the Get Lead Activities API to get a list of that activity ordered by date.

# return all available data values in Marketo

data_values_endpoint = "/rest/v1/activities/types.json"
data_values_url <- paste0(instance, data_values_endpoint, marketo_access_token,"&nextPageToken=",paging_token)

data_values_r <- GET(data_values_url)
headers(data_values_r)

# status code, 200 is successful. Common errors are 404 (file not found) and 403 (permission denied). 
# If you're talking to web APIs you might also see 500, which is a generic failure code (and thus not very helpful).
status_code(data_values_r)
http_status(data_values_r)

# args
content(data_values_r)

# look at the content
data_values <- str(content(data_values_r))
content(data_values_r, "text")

data_values

# Get Lead Activities Types ------------------------------------------------------
# http://developers.marketo.com/documentation/rest/get-lead-activities/
activities_endpoint <- "/rest/v1/activities.json"
activityTypeIDs <- "&activityTypeIds=13"
activities_url <- paste0(instance, activities_endpoint, marketo_access_token,
                         activityTypeIDs,"&nextPageToken=",paging_token)

# GET, parse with content, show structure
activities_r <- GET(activities_url)
headers(activities_r)
content(activities_r)
content(activities_r)$moreResult
str(content(activities_r))


# Grab 5 change data values -----------------------------------------------
activities_r <- GET(activities_url)
json.all <- NULL

for(i in seq(5)){
  
  if(content(activities_r)$moreResult == TRUE){
    # save nextPageToken to pass to next GET request
    json <- content(activities_r, "text")
    list <- content(activities_r)
    nextPageToken <- list$nextPageToken
    
    # deleting variables i don't need before joining lists
    #   list$success <- NULL
    #   list$nextPageToken <- NULL
    #   list$moreResult <- NULL
    json.all <- paste0(json.all, json)
    
    # next GET request  
    activities_url <- paste0(instance, activities_endpoint, marketo_access_token,
                             activityTypeIDs,"&nextPageToken=", nextPageToken)
    activities_r <- GET(activities_url)
    
    
  } else {
  }
  
}



# Grab ALL change data values ---------------------------------------------

#activities_df <- list()
json.all <- NULL

# check if there are moreResults, if TRUE, then keep going and appending output to activities_r
while (content(activities_r)$moreResult == TRUE){
  # save nextPageToken to pass to next GET request
  json <- content(activities_r, "text")
  list <- content(activities_r)
  nextPageToken <- list$nextPageToken
  
  # deleting variables i don't need before joining lists
  #   list$success <- NULL
  #   list$nextPageToken <- NULL
  #   list$moreResult <- NULL
  json.all <- paste0(json.all, json)
  
  # next GET request  
  activities_url <- paste0(instance, activities_endpoint, marketo_access_token,
                           activityTypeIDs,"&nextPageToken=", nextPageToken)
  activities_r <- GET(activities_url)
}

head(activities_df)

# Investigate change data values ALL --------------------------------------

#change_data_value.all <- activities_df

content(activities_r)
testjson <- content(activities_r, "text")

#gsub('\\', "", testjson, fixed = TRUE)

nchar(json.all)

# Raw JSON to data frame using tidyjson
df <- 
  json.all %>%
  spread_values(
    request_id = jstring("requestId")
  ) %>%
  enter_object("result") %>% gather_array() %>%
  spread_values(marketo_id = jstring("leadId")) %>%
  spread_values(time = jstring("activityDate")) %>%
  spread_values(activityTypeId = jstring("activityTypeId")) %>%
  spread_values(Type = jstring("primaryAttributeValue")) %>%
  enter_object("attributes") %>% gather_array() %>%
  spread_values(
    name = jstring("name"),
    value = jstring("value")
  ) 

# Raw JSON to data frame using jsonlite -----------------------------------
mydf <- fromJSON(json.all)
#throws an error about garbage

#trying stream_in

