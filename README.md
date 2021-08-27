# AWS Free Tier Launcher

## Description
This script is basically just a simple way to launch an EC2 using the AWS CLI without having to 
remember a bunch of IDs. I created this script during my internship with AWS, and wanting to make 
it easier to launch a free tier EC2 since I had to do it so frequently. Also I just wanted a reason
to mess with the CLI. 

This is likely not the most efficient way to do it, since `jq` has to parse through so much JSON, and I'm sure
something like this already exists, however I feel like there is a lot of potential for this tool.

### Dependencies
* [**`aws/aws-cli`**](https://github.com/aws/aws-cli) - unified command line interface to Amazon Web Services.
* [**`jq`**](https://stedolan.github.io/jq/) - lightweight and flexible command-line JSON processor.



