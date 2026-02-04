This file creates log groups and dashboards.
cat > cloudwatch.tf << 'ENDOFFILE'
resource "aws_cloudwatch_log_group" "vector_logs" {
  name              = "/vector/logs/application"
  retention_in_days = var.log_retention_days
  tags = { Application = "vector" }
}

resource "aws_cloudwatch_log_group" "vector_metrics" {
  name              = "/vector/logs/metrics"
  retention_in_days = var.log_retention_days
  tags = { Application = "vector" }
}

resource "aws_cloudwatch_log_group" "eks_cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_dashboard" "logs_dashboard" {
  dashboard_name = "${var.cluster_name}-logs-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 24, height = 6
        properties = {
          title = "Log Volume Over Time"
          region = var.aws_region
          metrics = [["AWS/Logs", "IncomingLogEvents", "LogGroupName", "/vector/logs/application", { stat = "Sum", period = 60 }]]
          view = "timeSeries"
        }
      },
      {
        type = "log", x = 0, y = 6, width = 12, height = 6
        properties = {
          title = "Log Level Distribution"
          region = var.aws_region
          query = "SOURCE '/vector/logs/application' | stats count(*) by level"
          view = "pie"
        }
      },
      {
        type = "log", x = 12, y = 6, width = 12, height = 6
        properties = {
          title = "Top Services by Volume"
          region = var.aws_region
          query = "SOURCE '/vector/logs/application' | stats count(*) as count by service | sort count desc | limit 10"
          view = "bar"
        }
      },
      {
        type = "log", x = 0, y = 12, width = 24, height = 6
        properties = {
          title = "Recent Error Logs"
          region = var.aws_region
          query = "SOURCE '/vector/logs/application' | filter level = 'error' | sort @timestamp desc | limit 100"
          view = "table"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "metrics_dashboard" {
  dashboard_name = "${var.cluster_name}-metrics-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 24, height = 6
        properties = {
          title = "Metrics Ingestion Rate"
          region = var.aws_region
          metrics = [["Vector/Metrics", "events_processed", "service", "vector", { stat = "Sum", period = 60 }]]
          view = "timeSeries"
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title = "CPU Usage by Service"
          region = var.aws_region
          metrics = [
            ["Vector/Application", "cpu_usage_percent", "service", "api-gateway", { stat = "Average" }],
            ["Vector/Application", "cpu_usage_percent", "service", "user-service", { stat = "Average" }]
          ]
          view = "timeSeries"
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title = "Memory Usage by Service"
          region = var.aws_region
          metrics = [
            ["Vector/Application", "memory_usage_bytes", "service", "api-gateway", { stat = "Average" }],
            ["Vector/Application", "memory_usage_bytes", "service", "user-service", { stat = "Average" }]
          ]
          view = "timeSeries"
        }
      }
    ]
  })
}
ENDOFFILE
