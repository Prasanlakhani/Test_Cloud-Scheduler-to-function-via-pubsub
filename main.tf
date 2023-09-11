# Set your GCP project ID
variable "project_id" {
  default = "ah-sandbox"
}

# Create a service account
resource "google_service_account" "function_sa" {
  account_id   = "cloudscloudf"
  display_name = "Service Account for Cloud Function"
  project      = var.project_id
}

# Assign roles to the service account
resource "google_project_iam_member" "function_sa_roles" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.function_sa.email}"
}

resource "google_storage_bucket" "bucket" {
  name                        = "prasan-test-sandbox2"
  location                    = "US"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
}

data "archive_file" "archive_code" {
  type        = "zip"
  source_dir  = pathexpand("code/")
  output_path = pathexpand("code.zip")
}

resource "google_storage_bucket_object" "archive" {
  name   = "code.zip"
  bucket = google_storage_bucket.bucket.name
  source              = data.archive_file.archive_code.output_path
  content_disposition = "attachment"
  content_encoding    = "gzip"
  content_type        = "application/zip"
}

# Create a Cloud Function
resource "google_cloudfunctions_function" "my_cloud_function" {
  name                  = "my-cloud-function"
  project               = var.project_id
  region                = "us-central1"
  runtime               = "python310" 
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name 
  entry_point           = "hello_pubsub"                            
  #trigger_http          = true
  #max_instance_count = 1
  available_memory_mb   = 256


	event_trigger {
    #trigger_region = "us-central1"
    #event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
	event_type     = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.schedule_function_topic.name
	#service= "pubsub.googleapis.com"
    #retry_policy   = "RETRY_POLICY_RETRY"
  }

  service_account_email = google_service_account.function_sa.email
}

# Create a Cloud Scheduler job
resource "google_cloud_scheduler_job" "schedule_function" {
  name    = "schedule-function-job"
  project = var.project_id
  #region = "us-central1"
  schedule = "every 1 hours" 


  pubsub_target {
    topic_name = "projects/${var.project_id}/topics/schedule-function-topic"
    #data = "Triggering Cloud Function"  
    data = base64encode("{\"Test\":\"No_1\"}")
  }
}

# Create a Pub/Sub topic for the Cloud Scheduler job
resource "google_pubsub_topic" "schedule_function_topic" {
  name    = "schedule-function-topic"
  project = var.project_id
}
