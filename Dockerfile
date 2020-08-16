FROM python:3.8

RUN apt-get update -y \
    && apt-get install -y jq \
    && pip install --upgrade pip \
    && pip install ansible==2.9.10 \
    && wget --output-document /tmp/terraform.zip https://releases.hashicorp.com/terraform/0.12.29/terraform_0.12.29_linux_amd64.zip \
    && (cd /tmp && unzip ./terraform.zip && mv ./terraform /usr/bin/ && rm /tmp/terraform.zip)

COPY ./entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

