# envs/newsapp/backend.oci.hcl
bucket    = "${{ secrets.TF_STATE_BUCKET }}"
namespace = "${{ secrets.OS_NAMESPACE }}"
region    = "${{ secrets.OCI_REGION }}"
key       = "${{ secrets.TF_STATE_KEY || "newsapp.tfstate" }}"
tenancy_ocid     = "${{ secrets.OCI_TENANCY_OCID }}"
user_ocid        = "${{ secrets.OCI_USER_OCID }}"   