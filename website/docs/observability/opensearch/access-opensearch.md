---
title: "Access OpenSearch"
sidebar_position: 10
---

In this section we will retrieve credentials for OpenSearch from the AWS Systems Manager Parameter Store, load pre-created OpenSearch dashboards for Kubernetes events and pod logs and confirm access to OpenSearch.  Load pre-created OpenSearch dashboards to display Kubernetes events and pods logs. The dashboards are available in [the file](https://github.com/VAR::MANIFESTS_OWNER/VAR::MANIFESTS_REPOSITORY/tree/VAR::MANIFESTS_REF/manifests/modules/observability/opensearch/opensearch-dashboards.ndjson) which includes the OpenSearch index patterns, visualizations and dashboards for Kubernetes events and pod logs.

```bash
$ export OPENSEARCH_DASHBOARD_FILE=~/environment/eks-workshop/modules/observability/opensearch/opensearch-dashboards.ndjson
$ export OPENSEARCH_DASHBOARD_LOAD_URL="https://$OPENSEARCH_HOST/_dashboards/api/saved_objects/_import?overwrite=true"
$ curl -s --aws-sigv4 "aws:amz:$AWS_REGION:aoss" -H "osd-xsrf: true" \
        -H "x-amz-security-token: $AWS_SESSION_TOKEN" \
        --user "$AWS_ACCESS_KEY_ID":"$AWS_SECRET_ACCESS_KEY" \
        -X POST $OPENSEARCH_DASHBOARD_LOAD_URL \
        --form file=@$OPENSEARCH_DASHBOARD_FILE | jq 'del(.successResults)'
{
  "successCount": 24,
  "success": true,
}
```

Retrieve the OpenSearch dashboard URL:

```bash
$ printf "\nhttps://%s/_dashboards/app/dashboards\n\n" "$OPENSEARCH_HOST" 
 
https://<host>.<region>.aoss.amazonaws.com/_dashboards/app/dashboards
```

Point your browser to the OpenSearch dashboard URL above and use the credentials to login.  You should see the dashboards that were loaded in the earlier step. The dashboards are currently empty since there is no data in OpenSearch yet. Keep this browser tab open or save the dashboard URLs. We will return to the dashboards in the next sections. Note that the dashboard will be empty at this point. In the upcoming sections, we will complete the steps to forward observability data to OpenSearch and populate these dashboards.

![OpenSearch login confirmation](./assets/opensearch-dashboard-launch.webp)
