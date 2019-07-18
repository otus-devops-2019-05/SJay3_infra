#!/usr/bin/python

''' dynamic inventory script
You need to install google-cloud-storage
pip install google-cloud-storage
'''
import os
import sys
import argparse
import re
import warnings
from google.cloud import storage

try:
    import json
except ImportError:
    import simplejson as json

#vars
prefix = 'stage'
gcp_bucket = 'sjay3-terraform-' + prefix
bucket_folder = 'reddit-' + prefix
path_to_state = gcp_bucket + '/' + bucket_folder + '/default.tfstate'

project = 'infra-244211'
zone = 'europe-west1-b'
warnings.filterwarnings("ignore") # ignor gcp warnings

class DynamicInventory(object):

    def __init__(self):
        self.inventory = {}
        self.read_cli_args()

        # Called with `--list`.
        if self.args.list:
            self.inventory = self.ansible_inventory()
            with open("inventory.json", "w") as data_file:
				json.dump(self.inventory, data_file, indent=4)

        # Called with `--host [hostname]`.
        elif self.args.host:
            # Not implemented, since we return _meta info `--list`.
            self.inventory = self.empty_inventory()
        # If no groups or vars are present, return an empty inventory.
        else:
            self.inventory = self.empty_inventory()

        print json.dumps(self.inventory);
                            # write ro inventory.json
       	


    # Example inventory for testing.
    def ansible_inventory(self):
    	#read bucket
		client = storage.Client()
		bucket = client.get_bucket(gcp_bucket)
		blob = bucket.get_blob(bucket_folder + '/default.tfstate')
		tfstate = blob.download_as_string()

		#print(tfstate)
		# deserialized json
		data = json.loads(tfstate)
		#print(data['modules'])

		tf_modules = data['modules']
		# print(tf_modules)

		group_app_hosts = []
		group_db_hosts = []
		

		for k in tf_modules:
			if k['resources']:
				for key,val in k['resources'].items():
					if re.match('google_compute_instance',key):
						#print(val['primary']['attributes'])
						if re.search('app',val['primary']['id']):
							group_app_hosts.append(val['primary']['attributes']['network_interface.0.access_config.0.nat_ip'])
						if re.search('db',val['primary']['id']):
							group_db_hosts.append(val['primary']['attributes']['network_interface.0.access_config.0.nat_ip'])
						

		inventory = {}
		if group_app_hosts:
			inventory['app'] = {}
			inventory['app']['hosts'] = group_app_hosts
		if group_db_hosts:
			inventory['db'] = {}
			inventory['db']['hosts'] = group_db_hosts
		inventory.update({'_meta':{'hostvars':{}}})
		#print inventory
		return inventory
        # return {
        #     'app': {
        #         'hosts': ['192.168.28.71', '192.168.28.72']
        #     },
        #     'db': {
        #     	'hosts': []
        #     },
        #     '_meta': {
        #         'hostvars': {
        #             '192.168.28.71': {
        #                 'host_specific_var': 'foo'
        #             },
        #             '192.168.28.72': {
        #                 'host_specific_var': 'bar'
        #             }
        #         }
        #     }
        # }

    # Empty inventory for testing.
    def empty_inventory(self):
        return {'_meta': {'hostvars': {}}}

    # Read the command line args passed to the script.
    def read_cli_args(self):
        parser = argparse.ArgumentParser()
        parser.add_argument('--list', action = 'store_true')
        parser.add_argument('--host', action = 'store')
        self.args = parser.parse_args()

# Get the inventory.
DynamicInventory()
