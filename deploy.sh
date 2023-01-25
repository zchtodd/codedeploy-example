aws deploy create-deployment \
  --application-name circumeo-app\
  --deployment-config-name CodeDeployDefault.OneAtATime \
  --deployment-group-name circumeo-deployment-group\
  --s3-location bucket=circumeo-codedeploy,bundleType=zip,key=app.zip\
  --region=us-east-2
