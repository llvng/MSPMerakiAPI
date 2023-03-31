################################# CODER #################################
### Created by Lewis Livingstone at Microbyte on 30/03/2023 to protect against 3CX Softphone Update vulnerable domains but can be used for future global blacklisting of URLs ###

################################# WHAT DOES IT DO #################################
## Connect to the Meraki API and loop through all organisations to update their content filter with a list of blocked URLs.
## If the organisation has a network and that network has a device with the model name beginning MX* then it will update the Content Filtering to block the URLs listed in the "$blockedurls" variable
## If the customer already has blocked URLs, it will not overwrite those, it will just add them to the list of blocked.

################################# PRE-REQUISITES #################################
# - API access must be enabled to each organisation that you want to modify - https://documentation.meraki.com/General_Administration/Other_Topics/Cisco_Meraki_Dashboard_API
# - All Meraki MX devices must have the Advanced Security license that enables Content Filtering otherwise you will receive 404 error
# - If your Meraki Content Filter is still using old categories, you may receive a "400 bad request" error - this is listed in Troubleshooting below. To check this before, navigate to the content filtering page of your customers' networks and see whether you are prompted to "merge" the categories. Complete this task and add a test blocked URL in manually, you should then be able to programmatically update them.

################################# TROUBLESHOOTING #################################
## I did have an issue where I was receiving "(400) Bad Request" because some of the content filtering categories were outdated and when I loaded the Content Filtering page in a browser, it allowed me to merge the new categories. I then had to add in a single blocked URL and then I was able to programmatically update the blocked URLs again.

################################# RESOURCES #################################
## I used the Cisco Meraki API Developer Documentation - it seemed quite hard to find: https://developer.cisco.com/meraki/api-v1/#!update-network-appliance-content-filtering

################################# PREVIOUS DEVELOPMENTS #################################
# COMPLETED - 30/03/2023 - 17:08 - A comparison between the $blockedURLs and the $existing_blocked to avoid the need to overwrite them, i.e. if the blocked URLs and the existing blocked URLs are the same then another web request would not need to be sent.
# COMPLETED - 30/03/2023 - 17:08 - It could also print the existing URLs to the screen for the user to review

################################# FUTURE DEVELOPMENTS #################################
## The below developments could be added in the future:
# - Error handling for the web requests to provide more usable information to the user
# - It could create a log file to see which were successful
# - CSV Import of blocked URLs?

# This is the API Key used to authenticate against the Meraki API
$key = 'ENTER-YOUR-API-KEY-HERE'

$Header = @{
    "X-Cisco-Meraki-API-Key" = $key
}

# Create a variable called $organisations which stores all of the organisation information from Meraki
$organisations = Invoke-RestMethod -Uri "https://api.meraki.com/api/v1/organizations" -Headers $Header -Method get -ContentType "application/json"

# Loop through each of the organisations and their networks to update the content filtering
foreach ($org in $organisations){

    # We have to add the blocked URLs from within the foreach loop so that it is overwritten each time it loops to the next element.
    # Otherwise, the previous customer's blocked URLs might be added to the next customer
    # Add in the URLs with a line break in between, i.e. just copy and paste from a plain text list
    $blockedurls =
    "akamaicontainer.com
    akamaitechcloudservices.com
    azuredeploystore.com
    azureonlinecloud.com
    azureonlinestorage.com
    dunamistrd.com
    glcloudservice.com
    journalide.org
    msedgepackageinfo.com
    msstorageazure.com
    msstorageboxes.com
    officeaddons.com
    officestoragebox.com
    pbxcloudeservices.com
    pbxphonenetwork.com
    pbxsources.com
    qwepoi123098.com
    sbmsa.wiki
    sourceslabs.com
    visualstudiofactory.com
    zacharryblogs.com
    msedgeupdate.net"

    # This will split the plain text list into individual items in a single object:
    $blockedurls = $blockedurls.Split("`n").Trim()

    # Create a PowerShell custom object called $json_object, even though it isn't yet it JSON format. It will then be added to with the next foreach loop.
    $json_object = [pscustomobject]@{
        blockedUrlPatterns = @()
    }
    # This loop will loop through the above URLs and add them as individual items into the $Json_object ready to be submitted as a body of a REST request
    foreach ($url in $blockedurls){
        $json_object.blockedUrlPatterns += $url
    }

    # This announces which organisation it is currently looping through and which index number of the total array it is using.
    # You may be able to use the index number to retrospectively run this whole script against a specific client but when I tested it, the index number changed each time. An example would be - "foreach ($org in $organisations[0])" where 0 is the index number. You may be able to do this if you were to sort the $organisations variable each time
    Write-Host "`nProcessing organisation: $($org.Name) - Index = $($organisations.IndexOf($org))" -ForegroundColor Magenta

    # Set the organisation ID to $org.id to be used in the next web request
    $organisation_id = $org.id

    # Get the current loop element's organisation's networks - i.e. if the customer has more than one site
    $organisation_networks = Invoke-RestMethod -Uri "https://api.meraki.com/api/v1/organizations/$($organisation_id)/networks" -Headers $Header -Method get -ContentType "application/json"

    # Loop through the networks for that customer and apply the content filtering
    foreach($network in $organisation_networks){
        
        # Get additional information about the devices within the network to be able to filter based on MX devices only
        $appliance_details = Invoke-RestMethod -Uri "https://api.meraki.com/api/v1/networks/$($network.Id)/devices" -Headers $Header -Method get -ContentType "application/json"

        # If the customer has a device in their network beginning with MX, then this will execute the Content Filter update, otherwise it will skip to the next network or customer.
        if ($appliance_details.Model -like "MX*"){

            # Print which network and device model is currently being processed
            Write-Host "   - Processing network: $($network.Name) - $($appliance_details.Model)" -ForegroundColor Blue
            
            # Get the content filtering information to check if there are any existing blocked URLs
            $content_filter = Invoke-RestMethod -Uri "https://api.meraki.com/api/v1/networks/$($network.Id)/appliance/contentFiltering" -Headers $Header -Method get -ContentType "application/json"
            
            # If the content filter's blocked URLs are currently blank, then just add in the above $blockedurls list.
            ## I had to use the ".length -eq 0" condition because the "$null -eq" didn't seem to work properly, presumably this is because it is a web request and has some hidden data within that variable.
            if($content_filter.blockedUrlPatterns.length -eq 0){
                
                # Print to the screen that no existing blocked URLs were found and that we will now add in the blocked ones
                Write-Host "   - No existing blocked URLs found in Content Filter - adding in new blocked URLs" -ForegroundColor Red
                
                # Now we know that there are no additional URLs to add to our original JSON object, we can convert it to JSON ready to submit as a "body" in the next REST request.
                $json_object = $json_object | ConvertTo-Json

                # This PUT request will update the current network's content filtering "blocked URLs" with the blocked URLs list - we write it to a variable so that the output doesn't print to the screen
                $updatecontentfilter = Invoke-RestMethod -Uri "https://api.meraki.com/api/v1/networks/$($network.Id)/appliance/contentFiltering" -Headers $Header -Method PUT -Body $json_object -ContentType "application/json"
                
                # This will print to the screen that the content filter has been updated
                Write-Host "   - Updated content filter with blocked URLs" -ForegroundColor Green

            # If the content filter has existing URLs in it, then it will execute the "else" section below to take the current URLs and add them to the blocked URLs list to update them all together
            } else {
                
                # Create a friendly variable off of the content filter containing all the existing blocked URLs
                $existing_blocked = $content_filter.blockedUrlPatterns

                # Print to the screen how many existing URLs it found and that it will be adding these to the blocked URLs list and removing any duplicates
                Write-Host "   - $($existing_blocked.Count) x Existing blocked URLs found in Content Filter" -ForegroundColor Yellow

                # Compare existing URLs to new blocked URLs
                # I want to be able to do the following:
                # 1. If there are URLs on the blocked URLs list above, but not in the customer's existing URLs then add ONLY these URLs whilst keeping the existing URLs
                # 2. If there are URLs not on the blocked list above, but are in addition, then nothing needs to be done
                $comparison = Compare-Object -DifferenceObject $blockedurls -ReferenceObject $existing_blocked
                
                # If the comparison has any URLs that are on the blocked URL list but NOT on the customer's existing URL list then add these URLs to the content filter block list
                if($comparison.SideIndicator -contains "=>"){

                    # Create a new variable called $new_urls to add the URLs that are NOT already on the customer's block list but are on the the above block list.
                    $new_urls = @()
                    
                    # Loop through the URLs in the comparison
                    foreach($url in $comparison){

                        # Only process the URLs where they appear in the "NEW LIST" not in the existing ones, i.e. existing ones are <= but new ones are =>
                        if($url.SideIndicator -eq "=>"){
                            # Add the $url to the $new_urls object
                            $new_urls += $url.InputObject
                        }
                    }
                    
                    # Create a variable containing the existing blocked URLs for the customer plus the $new_urls so not to overwrite any
                    $blockedurls = $existing_blocked += $new_urls

                    # Filter out any duplicates for the customer - needs to be an EXACT match
                    $blockedurls = $blockedurls | Select-Object -Unique

                    # Print how many new URLs were found and what they were
                    Write-Host "`n   - $($new_urls.Count) x new URLs were found, adding these to the Content Filter:" -ForegroundColor Green
                    $($new_urls)

                    # Now create a new PowerShell custom object, as we did above, with the existing URLs added to it
                    $json_object = [pscustomobject]@{
                        blockedUrlPatterns = @()
                    }

                    # This loop will loop through the above URLs and add them as individual items into the $Json_object ready to be submitted as a body of a REST request
                    foreach ($url in $blockedurls){
                        $json_object.blockedUrlPatterns += $url
                    }

                    # We can now convert our custom PowerShell Object to JSON ready to submit as a "body" in the next REST request.
                    $json_object = $json_object | ConvertTo-Json

                    # As above, we update the content filter with a PUT request with our "Body" of blocked URLs
                    $updatecontentfilter = Invoke-RestMethod -Uri "https://api.meraki.com/api/v1/networks/$($network.Id)/appliance/contentFiltering" -Headers $Header -Method PUT -Body $json_object -ContentType "application/json"

                    # This will print to the screen that the content filter has been updated
                    Write-Host "   - Updated content filter with blocked URLs" -ForegroundColor Green
                } else {
                    # This will print to the screen that no new URLs have been found and will progress to the next
                    Write-Host "   - No new URLs were found" -ForegroundColor Green
                }
            }
        }
    }
}