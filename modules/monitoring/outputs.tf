output "sns_topic_arn" {
  description = "ARN of the SNS alert topic"
  value       = aws_sns_topic.alerts.arn
}

output "cpu_alarm_name" {
  description = "Name of the EC2 CPU alarm"
  value       = aws_cloudwatch_metric_alarm.asg_cpu.alarm_name
}