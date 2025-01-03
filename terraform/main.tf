
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
   kubernetes = {
        source  = "hashicorp/kubernetes"
        version = "~> 2.0"
   }
  }
}

resource "random_string" "vertexAuth" {
  length           = 16
  special          = true
  
}



provider "google" {
  project = "ml-accelerator-dbarr"
  region  = "us-west1"
}

provider "kubernetes" {
  host                   = google_container_cluster.primary.endpoint
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}
# get the configuration for the current project
data "google_client_config" "current" {}
# Create a cluster in GKE
resource "google_container_cluster" "primary" {
  name     = "llm-app-cluster"
  location = "us-west1"

   initial_node_count = 3

  node_config {
        machine_type = "e2-medium"
     }
}
# Kubernetes namespace
 resource "kubernetes_namespace" "llm_app" {
    metadata {
    name = "llm-app"
    }
 }

 resource "kubernetes_secret" "vertex-auth" {
    metadata {
       name = "vertex-auth"
       namespace = kubernetes_namespace.llm_app.metadata.0.name
    }

    data = {
       vertex_cf_auth_token = random_string.vertexAuth.result
       test_token = "monkey"
    }

    type = "kubernetes.io/generic"
 }

# Deploy the app
 resource "kubernetes_deployment" "llm_app_deployment" {
    depends_on = [
       kubernetes_secret.vertex-auth,
    ]
    metadata {
       name      = "llm-app"
       namespace = kubernetes_namespace.llm_app.metadata.0.name
       labels = {
          app = "llm-app"
       }
    }
    spec {
       replicas = 2
       selector {
          match_labels = {
            app = "llm-app"
         }
     }
     template {
        metadata {
          labels = {
           app = "llm-app"
         }
        }
        spec {
           container {
             name = "llm-app-container"
             image = "us-docker.pkg.dev/ml-accelerator-dbarr/explore-assistant-gke/explore-assist-gke@sha256:2cb4e80b8b580f20eb9e096b1cf1ef1c7cfb071340e27407ab76bcc2292c9a7b"
             env_from {
              secret_ref {
                name = "vertex-auth"
              }
             }
             port {
                container_port = 8000
             }
           }
        }
    }
 }
 }
 resource "kubernetes_service" "llm_app_service" {
    metadata {
        name      = "llm-app-service"
        namespace = kubernetes_namespace.llm_app.metadata.0.name
        labels = {
         app = "llm-app"
         }
     }
    spec {
         selector = {
            app = "llm-app"
         }
         type = "LoadBalancer"
        port {
             port        = 80
             target_port = 8000
           }
    }
  }
 output "vertex-auth"{
   value= random_string.vertexAuth.result
 }
