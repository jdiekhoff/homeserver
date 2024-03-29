FROM semaphoreui/semaphore:v2.9.45

# CA Cert of the homelab is not in the trusted certs for the semaphore image.
# I have modified the ca-certificates file from the semaphore image, and this will copy
# a new cert into the container with the homelab root ca.

ADD ca-certificates.crt /etc/ssl/certs/ca-certificates.crt