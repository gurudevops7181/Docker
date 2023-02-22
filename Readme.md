1. ES Needs more memory, deploy the stack with 4GB machines with EFK Stack.

2. Create overlay network named as efk
   docker network create efk --driver overlay

3. Create FluentD Configmap
   docker config create conf ./fluentd/conf/fluent.conf
   
   
