resource "aws_kms_key" "eks" {
    description = "KMS key for EKS cluster ${var.cluster_name} encryption"
    deletion_window_indays = 7
    enable_key_rotation = true 

    tags = merge{
        var.tags,
        {
            Name = "${var.cluster_name}-eks-kms"

        }
    }
}

resource "aws_kms_alias" "eks " {
    name = "alias/${var.cluster_name}-eks"
    target_key_id = aws_kms_key.eks.key_id

}

resource "aws_cloudwatch_log_group" "eks" {
    name = "/aws/eks/${var.cluster_name}/cluster"
    retention_in_days = 7

    tags = var.tags
}