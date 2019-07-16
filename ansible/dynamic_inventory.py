#!/usr/bin/python

''' inventory script for ansible
You need to install google-api-python-client and google-cloud-storage
pip install --upgrade google-api-python-client
pip install google-cloud-storage
'''

import json
import googleapiclient.discovery
from google.cloud import storage

prefix = 'stage'
gcp_bucket = 'sjay3-terraform-' + prefix
bucket_folder = 'reddit-' + prefix
path_to_state = gcp_bucket + '/' + bucket_folder + '/default.tfstate'

project = 'infra-244211'
zone = 'europe-west1-b'

# authorize in GCP
#compute = googleapiclient.discovery.build('compute', 'v1')

def list_instances(compute, project, zone):
    result = compute.instances().list(project=project, zone=zone).execute()
    return result['items'] if 'items' in result else None

# instances = list_instances(compute, project, zone)

# for instance in instances:
#         print(' - ' + instance['name'])

#read bucket
client = storage.Client()
bucket = client.get_bucket(gcp_bucket)
blob = bucket.get_blob(bucket_folder + '/default.tfstate')
tfstate = blob.download_as_string()

#print(tfstate)
# deserialized json
data = json.loads(tfstate)
print(data['modules'])


