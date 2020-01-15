resource "aws_ecr_repository" "back_end" {
  name                 = "esgi-cloud-project-back_end"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecs_cluster" "back_end" {
  name = "esgi_cloud_back_end"
}

resource "aws_iam_role" "back_end_elastic_container" {
  name = "esgi_cloud_back_end_elastic_container"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "back_end_elastic_container" {
  name = "esgi_cloud_elastic_container"
  role = "${aws_iam_role.back_end_elastic_container.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect":"Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:GetBucketVersioning"
      ],
      "Resource": [
        "${aws_s3_bucket.back_end_code_pipeline.arn}",
        "${aws_s3_bucket.back_end_code_pipeline.arn}/*"
      ]
    },
    {
        "Effect": "Allow",
        "Action": [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:BatchGetImage",
            "ecr:GetDownloadUrlForLayer"
        ],
        "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_ecs_task_definition" "back_end" {
  family                = "esgi_cloud_back_end"
  container_definitions = "${file("task_definitions_service.json")}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn = "${aws_iam_role.back_end_elastic_container.arn}"
}

resource "aws_ecs_service" "back_end" {
  name            = "esgi_cloud_back_end"
  cluster         = "${aws_ecs_cluster.back_end.id}"
  task_definition = "${aws_ecs_task_definition.back_end.arn}"
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_tasks.id]
    subnets          = aws_subnet.private.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.app.id
    container_name   = "esgi_cloud_back_end"
    container_port   = 8080
  }

  depends_on = [aws_alb_listener.front_end]
}