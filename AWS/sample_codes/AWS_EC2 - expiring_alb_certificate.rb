# Copyright (c) 2013, 2014, 2015, 2016, 2017, 2018, 2018. Evident.io (Evident). All Rights Reserved. 
# 
#   Evident.io shall retain all ownership of all right, title and interest in and to 
#   the Licensed Software, Documentation, Source Code, Object Code, and API's ("Deliverables"), 
#   including (a) all information and technology capable of general application to Evident.io's
#   customers; and (b) any works created by Evident.io prior to its commencement of any
#   Services for Customer.
# 
# Upon receipt of all fees, expenses and taxes due in respect of the relevant Services, 
#   Evident.io grants the Customer a perpetual, royalty-free, non-transferable, license to 
#   use, copy, configure and translate any Deliverable solely for internal business operations
#   of the Customer as they relate to the Evident.io platform and products, and always
#   subject to Evident.io's underlying intellectual property rights.
# 
# IN NO EVENT SHALL EVIDENT.IO BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, 
#   INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING OUT OF 
#   THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF EVIDENT.IO HAS BEEN HAS BEEN
#   ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# EVIDENT.IO SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
#   THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. 
#   THE SOFTWARE AND ACCOMPANYING DOCUMENTATION, IF ANY, PROVIDED HEREUNDER IS PROVIDED "AS IS". 
#   EVIDENT.IO HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS,
#   OR MODIFICATIONS.
#
# Description:
#
# Ensure that your ALB SSL/TLS certificates are renewed.
# 
# Default Conditions:
#
# - PASS: SSL certificate does not expire within the specified fail, or warn days
# - WARN: SSL certificate expires within the specified warn days
# - FAIL: SSL certificate has expired, or expires within the specified fail days
#
# Remediation:
#
# - Renew your certificate
# - Update ALB SSL certificate 
#   https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-update-certificates.html
#

#    ______     ___     ____  _____   ________   _____     ______   
#  .' ___  |  .'   `.  |_   \|_   _| |_   __  | |_   _|  .' ___  |  
# / .'   \_| /  .-.  \   |   \ | |     | |_ \_|   | |   / .'   \_|  
# | |        | |   | |   | |\ \| |     |  _|      | |   | |   ____  
# \ `.___.'\ \  `-'  /  _| |_\   |_   _| |_      _| |_  \ `.___]  | 
#  `.____ .'  `.___.'  |_____|\____| |_____|    |_____|  `._____.'  
#

# Options
#
@options = {
  # Warn/Fail alert if certificate expires in number of days
  #
  warn_days: 90,
  fail_days: 30
}

#    ______   ____  ____   ________     ______   ___  ____     ______   
#  .' ___  | |_   ||   _| |_   __  |  .' ___  | |_  ||_  _|  .' ____ \  
# / .'   \_|   | |__| |     | |_ \_| / .'   \_|   | |_/ /    | (___ \_| 
# | |          |  __  |     |  _| _  | |          |  __'.     _.____`.  
# \ `.___.'\  _| |  | |_   _| |__/ | \ `.___.'\  _| |  \ \_  | \____) | 
#  `.____ .' |____||____| |________|  `.____ .' |____||____|  \______.' 
#

configure do |c|
  c.deep_inspection   = [:load_balancer_name, :load_balancer_dns_name, :expire_date, :days_left, :load_balancer_listener, :region]
end

def perform(aws)
    
  @options[:warn_days].nil? ? warn_days = 90 : warn_days = @options[:warn_days]
  @options[:fail_days].nil? ? fail_days = 30 : fail_days = @options[:fail_days]
  
  elbs   = aws.elbv2.describe_load_balancers()[:load_balancers]
  min_days_left = 99999999999999
  min_listener = ''
  min_expire_date = ''
  region = aws.region

  elbs.each do | elb |
    elb_name     = elb[:load_balancer_name]
    elb_arn      = elb[:load_balancer_arn]
    elb_dns_name = elb[:dns_name]
    elb_listeners = aws.elbv2.describe_listeners({ load_balancer_arn: elb_arn })[:listeners]

    elb_listeners.each do | listener |
      elb_port     = listener[:port]
      elb_protocol = listener[:protocol]

      if (elb_protocol == "HTTPS")
        elb_ssl_certificates = aws.elbv2.describe_listener_certificates({ listener_arn: listener[:listener_arn] })[:certificates]

        elb_ssl_certificates.each do | certificate |
          elb_ssl_certificate_id = certificate[:certificate_arn]
          expire_date = nil

          if elb_ssl_certificate_id =~ /arn:aws:acm/
            cert = aws.acm.describe_certificate({ certificate_arn: elb_ssl_certificate_id })[:certificate]
            expire_date = cert[:not_after].to_datetime
          end

          if elb_ssl_certificate_id =~ /arn:aws:iam/
            certs = aws.iam.list_server_certificates()[:server_certificate_metadata_list]
            certs.each do | cert |
              if (cert[:arn] == elb_ssl_certificate_id)
                expire_date = cert[:expiration].to_datetime
              end
            end
          end

          now = Date.today
          days_left = (expire_date - now).to_i - 1
          if days_left < min_days_left then
            min_days_left = days_left
            min_listener = listener
            min_expire_date = expire_date
          end
        end
      end
    end

    set_data(load_balancer_name: elb_name, load_balancer_dns_name: elb_dns_name, expire_date: min_expire_date, days_left: min_days_left, load_balancer_listener: min_listener, region: region)

    if (min_days_left < 0)
      fail(message: "SSL Certificate for ELB #{elb_name} has expired.", resource_id: elb_name)
    elsif (min_days_left < fail_days)
      fail(message: "SSL Certificate for ELB #{elb_name} expires in less than #{fail_days} days.", resource_id: elb_name)
    elsif (min_days_left > fail_days && min_days_left < warn_days)
      warn(message: "SSL Certificate for ELB #{elb_name} within #{warn_days} days.", resource_id: elb_name)
    elsif (min_days_left >= warn_days)
      pass(message: "SSL Certificate for ELB #{elb_name} won't expire for more than #{warn_days} days.", resource_id: elb_name)
    end
  end
end
