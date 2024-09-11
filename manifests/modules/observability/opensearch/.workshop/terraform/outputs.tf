output "environment_variables" {
  description = "Environment variables to be added to the IDE shell"
  value = {
    LAMBDA_ARN      = aws_lambda_function.eks_control_plane_logs_to_opensearch.arn
    LAMBDA_ROLE_ARN = aws_iam_role.lambda_execution_role.arn
    OPENSEARCH_DASHBOARD_ENDPOINT = aws_opensearchserverless_collection.eks_collection.dashboard_endpoint
    OPENSEARCH_COLLECTION_ENDPOINT = aws_opensearchserverless_collection.eks_collection.collection_endpoint
  }
}