output "instance_ip_addr" {
  value = aws_instance.mtc_ec2.public_ip
}
