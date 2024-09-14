output "environment_variables" {
  description = "Environment variables to be added to the IDE shell"
  value = {
    LAMBDA_ARN = aws_lambda_function.export_to_opensearch.arn
    OPENSEARCH_HOST = replace(aws_opensearchserverless_collection.eks_collection.collection_endpoint, "https://", "")
    OPENSEARCH_IRSA_ARN = aws_iam_role.opensearch_exporter_irsa.arn
  }
}