FROM centos:7

ADD https://storage.googleapis.com/kubernetes-release/release/v1.13.2/bin/linux/amd64/kubectl /usr/local/bin
COPY inner.sh /usr/local/bin
RUN chmod +x /usr/local/bin/inner.sh /usr/local/bin/kubectl

CMD /usr/local/bin/inner.sh