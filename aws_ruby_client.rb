#!/usr/bin/env ruby
require 'securerandom'
require 'rubygems'
require 'aws/s3'
require 'right_aws'
require 'green_shoes'
def upload(local_file,bucket,met,thu)
begin
mime_type = "application/octet-stream" 
access_key_id = 'XXXXXXXXXXXXXXXXX'
secret_access_key = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
AWS::S3::Base.establish_connection!(
 :access_key_id     => 'XXXXXXXXXXXXXXX',
  :secret_access_key => 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
)
#access_key_id and secret_access_key in order to establish connection with S3 and SQS
base_name = File.basename(local_file)
puts "Uploading #{local_file} as '#{base_name}' to '#{bucket}'"
AWS::S3::S3Object.store(base_name,File.open(local_file),bucket, :content_type => 'image/jpg')

#storing image in S3
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

p num
if thu == 1
	mes1 = sqs.queue(input1)
	mes1.push("thumbnail,"+base_name+","+bucket+","+num)
end
if met == 1
	mes2 = sqs.queue(input2)
	mes2.push("metadata,"+base_name+","+bucket+","+num)
end
#sending message1 and message2, mes1 is sent in input1 queue in order to  request
#for the thumbnail
#and mes2 is sent in input2 queue in order to request for metadata   
waiting = false
i =0
#this loop waits for the responce by scanning output queue and error queue
out = sqs.queue(stdout)
err = sqs.queue(stderr)
output = ""
while (i!=2)
	if met == 0
		i = 1
	end
	if thu == 0
		i = 1
	end 
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
if AWS::S3::S3Object.delete(local_file,bucket) #deletes image send on S3 
p 'deletes'				       
end
rescue Exception=>e #If anything goes wrong print to GUI
	oi = e.to_s
	p oi
	return "AppError"+"`"+oi
end
p output
return output
end

def clearALL()		#If many unread messages are in the queues the programme will
input1 = 'input1' 	#be slower to find the right message. If anything has gone wrong
input2 = 'input2'	#by pressing "clear" they can empty all queues and start over.
stdout = 'stdout'
stderr = 'stderr'
access_key_id = 'XXXXXXXXXXXXXXXXx'
secret_access_key = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'
sqs = RightAws::SqsGen2.new(access_key_id, secret_access_key)
ip1 = RightAws::SqsGen2::Queue.create(sqs,input1,true)
ip2 = RightAws::SqsGen2::Queue.create(sqs,input2,true)
out = RightAws::SqsGen2::Queue.create(sqs,stdout,true)
err = RightAws::SqsGen2::Queue.create(sqs,stderr,true)
ip1.clear()
ip2.clear()
out.clear()
err.clear()
end

output= ""
images = ""
backets= ""
Shoes.app( :width => 300, :height => 400) do #Shoes.app takes care of the GUI part
	stack
	output = ""
	@back  = background red
	@text  = para "Select Image"
	@image = edit_line 
	@text1  = para "Select Bucket"
	@backet = edit_line
	flow {@meta = check; para "Metadata" ,width: 200}
	flow {@thumb = check; para "Thumbnail" ,width: 200}
	@b1 = button "Go!"
  	@b1.click do
	if @image.text.eql?("") || @backet.text.eql?("")
		@caution.text = "please fill in image and bucket information"
		next
	end
	if (@meta.checked? == false && @thumb.checked? == false)
		@caution.text = "No procedures selected"
		next
	end
	if @meta.checked?
		met = 1
	else	
		met = 0
	end
	if @thumb.checked?
		thu = 1
	else
		thu = 0
	end
	imegek,metak,data1,data2,data3,data =nil
	output = upload(@image.text.to_s,@backet.text.to_s,met,thu)
	p output
	data,data1,data2,data3 = output.split("`")
	p data
	p data1
	p data2
	p data3
	if data.eql?("AppError")
		@caution.text = data1
		next
	end
	if data.eql?("ERROR") && data2.eql?("ERROR")
		@caution.text = "Server returned an error"
		Shoes.app do #If there is an error in error queue pop-up a window 
		para data1  #with the output error message
		para data3
	end
	elsif data2.eql?("ERROR")
		@caution.text = "Server returned an error"
		Shoes.app do #If there is an error in error queue pop-up a window 
		para data3
	end
	elsif data.eql?("ERROR")
	     Shoes.app do #If there is an error in error queue pop-up a window 
		para data1
		end
	end
	if data.eql?("image") && data2.eql?("metadata")
			imagek = data1
			metak = data3
			@caution.text = "Done!"
			Shoes.app  do #When upload finishes pop-up a windows with the
			if  imagek!=nil
				image imagek  #thumbnail and the metadata
			end
			para metak
			end
	elsif data2.eql?("image") && data.eql?("metadata")
			imagek = data3
			metak = data1
			@caution.text = "Done!"
			Shoes.app  do #When upload finishes pop-up a windows with the
			if  imagek!=nil
				image imagek  #thumbnail and the metadata
			end
			para metak
			end
	 elsif data2.eql?("image") || data.eql?("image")
                        if data2.eql?("image")
				imagek = data3
                        elsif data.eql?("image")
				imagek = data1
			end
                        @caution.text = "Done!"
			Shoes.app  do #When upload finishes pop-up a windows with the
                                image imagek  #thumbnail 
                        end
	elsif data2.eql?("metadata") || data.eql?("metadata")
                        if data2.eql?("metadata")
                                metak = data3
                        elsif data.eql?("metadata")
                                metak = data1
                        end
                        @caution.text = "Done!"
                        Shoes.app  do #When upload finishes pop-up a windows with the
				para metak  # metadata
                        end
 	end
	end
	@b3 = button "Empty" #Calls clearALL
	@b3.click {clearALL()}
	@b2 = button "Exit"  #Exits the programme
	@b2.click {exit()}
	@caution = para
end

