output "fis_experiment_template_id" {
  description = "AWS FIS experiment template ID for the Game Day ECS task stop exercise (Issue #447, moved from terraform/service in Issue #458)"
  value       = module.fis.experiment_template_id
}
