1. To make this work you first need a GCP project and to have your ADC credentials setup as described here: https://cloud.google.com/docs/authentication/production
2. Replace my user name in **inventory.yaml** with your user name
3. Update **params.json** to set `gcp_project` to your project's name
4. Tweak **params.json** so that all IP address ranges you need open are included in `firewall_allow`
5. Run `bolt plan run onebuttonpe --params @params.json`
6. Wait...takes longer than you'd think to upload PE archives to instances so if you're at home with terrible upload speeds, go have lunch and if you've done that already...