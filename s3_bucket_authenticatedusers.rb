configure do |c|
    c.deep_inspection = [:bucket_name, :acl]
    c.valid_regions = [:us_east_1]
    c.unique_identifier = [:bucket_name]
end

def perform(aws)
    
    aws.s3.list_buckets[:buckets].each do |bucket|
        acl = nil
        name = bucket[:name]
        
        acl = aws.s3.get_bucket_acl(bucket: name)
        acl.grants.each do |grant|
            permission = grant.permission
            grantee = grant.grantee
            set_data(bucket_name: name, acl: acl, bucket: bucket)


            if grantee.uri != nil
                if grantee.uri =~ /AuthenticatedUsers$/
                  fail(message: "Bucket uses AuthenticatedUsers permission #{name}", resource_id: name)
                end

            end
       
        end


    end

end


