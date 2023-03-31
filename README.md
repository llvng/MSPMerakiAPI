# Created by Lewis Livingstone at Microbyte on 30/03/2023 to protect against 3CX Softphone Update vulnerable domains but can be used for future global blacklisting of URLs ###

# WHAT DOES IT DO
- Connect to the Meraki API and loop through all organisations to update their content filter with a list of blocked URLs.
- If the organisation has a network and that network has a device with the model name beginning MX* then it will update the Content Filtering to block the URLs listed in the "$blockedurls" variable
- If the customer already has blocked URLs, it will not overwrite those, it will just add them to the list of blocked.

# PRE-REQUISITES
- API access must be enabled to each organisation that you want to modify - https://documentation.meraki.com/General_Administration/Other_Topics/Cisco_Meraki_Dashboard_API
- All Meraki MX devices must have the Advanced Security license that enables Content Filtering otherwise you will receive 404 error
- If your Meraki Content Filter is still using old categories, you may receive a "400 bad request" error - this is listed in Troubleshooting below. To check this before, navigate to the content filtering page of your customers' networks and see whether you are prompted to "merge" the categories. Complete this task and add a test blocked URL in manually, you should then be able to programmatically update them.

# TROUBLESHOOTING
- I did have an issue where I was receiving "(400) Bad Request" because some of the content filtering categories were outdated and when I loaded the Content Filtering page in a browser, it allowed me to merge the new categories. I then had to add in a single blocked URL and then I was able to programmatically update the blocked URLs again.

# RESOURCES
- I used the Cisco Meraki API Developer Documentation - it seemed quite hard to find
    - https://developer.cisco.com/meraki/api-v1/#!update-network-appliance-content-filtering
- Set up the API Keys for your org
    - https://documentation.meraki.com/General_Administration/Other_Topics/Cisco_Meraki_Dashboard_API

# PREVIOUS DEVELOPMENTS
- COMPLETED - 30/03/2023 - 17:08 - A comparison between the $blockedURLs and the $existing_blocked to avoid the need to overwrite them, i.e. if the blocked URLs and the existing blocked URLs are the same then another web request would not need to be sent.
- COMPLETED - 30/03/2023 - 17:08 - It could also print the existing URLs to the screen for the user to review

# FUTURE DEVELOPMENTS
- The below developments could be added in the future:
    - Error handling for the web requests to provide more usable information to the user
    - It could create a log file to see which were successful
    - CSV Import of blocked URLs?