#!/usr/bin/env ruby
require 'securerandom'
require 'rubygems'
require 'aws/s3'
require 'right_aws' 
require 'open3'

local_file = ARGV[0]
bucket = ARGV[1]
thumbn = ARGV[2]
metad = ARGV[3]
mime_type = "application/octet-stream"
if ARGV[0].eql?(nil) || ARGV[1].eql?(nil) || ARGV[2].eql?(nil) || ARGV[3].eql?(nil)
	p "Wrong arguments , usage: ruby1.9.1 s3term [image file] [bucket] [yes/no] [yes/no]"
	exit
end

access_key_id = 'XXXXXXXXXXXXXXXXXXXx'
secret_access_key = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'

AWS::S3::Base.establish_connection!(
 :access_key_id     => 'XXXXXXXXXXXXXXXXXXXXX',
  :secret_access_key => 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXx'
)
base_name = File.basename(local_file)
puts "Uploading #{local_file} as '#{base_name}' to '#{bucket}'"
AWS::S3::S3Object.store(base_name,File.open(local_file),bucket, :content_type => 'image/jpg')

puts "Uploaded!"
input1 = 'input1'
input2 = 'input2'
stdout = 'stdout'
stderr = 'stderr'
sqs = RightAws::SqsGen2.new(access_key_id, secret_access_key) 
ip1 = RightAws::SqsGen2::Queue.create(sqs,input1,true)
ip2 = RightAws::SqsGen2::Queue.create(sqs,input2,true)
out = RightAws::SqsGen2::Queue.create(sqs,stdout,true)
err = RightAws::SqsGen2::Queue.create(sqs,stderr,true)
#establishing connection with SQS Queues
num = SecureRandom.base64
#generating random unique number in order to pair incoming and outcoming messages
i=0
p num
if thumbn.eql?("yes")
	mes1 = sqs.queue(input1)
	mes1.push("thumbnail,"+base_name+","+bucket+","+num)
end
if metad.eql?("yes")
	mes2 = sqs.queue(input2)
	mes2.push("metadata,"+base_name+","+bucket+","+num)
end
if metad.eql?("yes") && thumbn.eql?("no")
	i =1
elsif metad.eql?("no") && thumbn.eql?("yes")
	i =1
elsif metad.eql?("no") && thumbn.eql?("no")
	p "no procedure selected"
	AWS::S3::S3Object.delete(local_file,bucket)	
	exit
end
#sending message1 and message2, mes1 is sent in input1 queue in order to  request
#for the thumbnail
#and mes2 is sent in input2 queue in order to request for metadata   
waiting = false
#this loop waits for the responce by scanning output queue and error queue
out = sqs.queue(stdout)
err = sqs.queue(stderr)
output = ""
while (i!=2)
        outm = out.pop
        errm = err.pop
        if outm != nil #if queue is empty it returns nil
                imes = outm.to_s #receiving messages from output queue
                num2,text,url = imes.split("`")
		if num.eql?(num2) #when message received it compares the number of
                        i=i+1	  #the message with the number generated earlier
			if text.eql?("image")
                        	output = output+text+"`"+url+"`"
                	elsif text.eql?("metadata")
				output = output+text+"`"+url+"`"
			end
		elsif
                        out.push(imes) #if number isn't equal it resends the message in the top
                end		       #of the queue in order to check the next one.
        end			       #this way the messages will not be mixed with other 
        if errm != nil		       #messages if more than one instances of the programme
                ierr = errm.to_s       #is running
                num2,text,error = ierr.split("`")
                if num.eql?(num2)      #receiving messages from error queue
                        i=i+1
                        output = output +text+"`"+error+"`"
                elsif
                        err.push(ierr)
                end
        end
end
p output
if AWS::S3::S3Object.delete(local_file,bucket) #deletes image send on S3 
	p 'deletes'				       
end
