output "experiment_template_id" {
  description = "ID of the FIS experiment template (used by the game-day script to start-experiment)"
  value       = aws_fis_experiment_template.ecs_task_stop.id
}
