require 'rubygems'
require 'aws/s3'
require 'right_aws'
require 'RMagick'
require 'exifr'
require 'tempfile'
require 'magick-metadata'
require 'yaml'
access_key_id = 'XXXXXXXXXXXXXXXXX'
secret_access_key = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'

AWS::S3::Base.establish_connection!(
 :access_key_id     => 'XXXXXXXXXXXXXXXX',
  :secret_access_key => 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXx'
)
#establishes connnection with S3 and SQS
sqs = RightAws::SqsGen2.new(access_key_id, secret_access_key)
waiting = false
def error(num,type,mes,sqs) #if imageRet produces an error it will be send in the error queue for the client to read
	err = sqs.queue('stderr')
	err.push(num+"`"+"ERROR`"+mes.to_s)
end

def imageRet(mes,sqs) #imageRet is called when a message in Input1 or Input2 is present
	begin
	outm = ""
	errm = ""
	oi = mes.to_s
	type,name,bucket,num = oi.split(",") 
	imgtemp = AWS::S3::S3Object.find(name,bucket) #Retrieves image from S3 based on message's info
	file = Tempfile.new(['foo','.jpg']) #makes temporary file to store image
	oi = file.path
	myfile = File.open(oi,'w') 
	myfile.puts  imgtemp.value #copy image to temp file
	myfile = File.open(oi,'r')
	f = Magick::Image::read(myfile)[0]
	if type.eql?("metadata") #if message has a flag for metadata
		p "OKmeta" + type
		image_path = oi
		data = MagickMetadata.new(image_path)
		p data
		fin =  data.to_yaml
		fin = fin.to_s
		file_to_up = Tempfile.new(['soo','.txt'])
		oids = file_to_up.path
		File.open(oids,'w') do |line|
      		line.puts fin
    		end
		myfilemet = File.open(oids,'r')
		p myfilemet.read
		base_name = File.basename(name)
		AWS::S3::S3Object.store("metadata_"+base_name+".txt",open(myfilemet),bucket)
		outm = num+"`"+"metadata`" + fin 
				#and sends the output message with the metadata
	end
	if type.eql?("thumbnail") #if message has a flag for metadata
		p "OKthumb" +type
		thumb = f.scale(125, 125) #produces thumbnail file
		thumb.write myfile.path
		base_name = File.basename(name)
		AWS::S3::S3Object.store("thumbnail_"+base_name,open(myfile),bucket) #sends it to S3
		outm =  num+"`"+"image`" + (AWS::S3::S3Object.url_for("thumbnail" +base_name, bucket)).to_s
		p outm	#produces output message with the URL for the thumbnail file
	end
	out = sqs.queue('stdout')
	out.push(outm) #sends the output message to stdout queue
	
	rescue Exception=>e  
	p e
	err = sqs.queue('stderr')
	error(num,type,e,sqs) #If an error is raised call error function in order to send message in error queue
	

end	
end
mes1 = sqs.queue('input1')
mes2 = sqs.queue('input2')
out = sqs.queue('stderr')
err = sqs.queue('stdout')
while (waiting == false) #pulling messages from input1 and input2 until a message is found
	qr = mes1.pop
	if qr != nil
	imageRet(qr,sqs)
	end
	qr = mes2.pop
	if qr != nil
	imageRet(qr,sqs)
	end
end

