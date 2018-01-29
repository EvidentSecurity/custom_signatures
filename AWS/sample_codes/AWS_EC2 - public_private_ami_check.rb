#
# Copyright (c) 2013, 2014, 2015, 2016, 2017, 2018. Evident.io (Evident). All Rights Reserved. 
#   Evident.io shall retain all ownership of all right, title and interest in and to 
#   the Licensed Software, Documentation, Source Code, Object Code, and API's ("Deliverables"), 
#   including (a) all information and technology capable of general application to Evident.io's customers; 
#   and (b) any works created by Evident.io prior to its commencement of any Services for Customer. 
#
# Upon receipt of all fees, expenses and taxes due in respect of the relevant Services, 
#   Evident.io grants the Customer a perpetual, royalty-free, non-transferable, license to 
#   use, copy, configure and translate any Deliverable solely for internal business operations of the Customer 
#   as they relate to the Evident.io platform and products, 
#   and always subject to Evident.io's underlying intellectual property rights.
#
# IN NO EVENT SHALL EVIDENT.IO BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, 
#   INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING OUT OF 
#   THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, 
#   EVEN IF EVIDENT.IO HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# EVIDENT.IO SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
#  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. 
#  THE SOFTWARE AND ACCOMPANYING DOCUMENTATION, IF ANY, PROVIDED HEREUNDER IS PROVIDED "AS IS". 
#  EVIDENT.IO HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS.
#

# Description:
# Check for public AMI
# 
# AMIs can be shared publicly, but in almost all cases should not due to risk
# in exposing sensitive data.
# 
# Resolution:
# In the AWS Console:
# * Open the Amazon EC2 console at https://console.aws.amazon.com/ec2/.
# * In the navigation pane, choose AMIs.
# * Select your AMI in the list, and then choose Modify Image Permissions from the Actions list.
# * Choose Private and choose Save.
#
# In the aws-cli:
# * aws ec2 modify-image-attribute --image-id ami-XXXXXXXX --launch-permission "{\"Remove\":[{\"Group\":\"all\"}]}"


##
configure do |c|
    c.deep_inspection = [:image_id, :name, :description, :public, :tags]
    c.unique_identifier  = [:image_id]
end

# Required perform method
def perform(aws)
    @images = aws.ec2.describe_images({owners: ["self"]}).images
    alert_images()
end

def alert_images()
    @images.each do |image|
        image_id = image[:image_id]
        is_public = image[:public]
        set_data(image)
        
        if is_public == true
            fail(message: "AMI #{image_id} is shared publicly", resource_id: image_id)
        else
            pass(message: "AMI #{image_id} is private", resource_id: image_id)
        end
        
        
    end
end
