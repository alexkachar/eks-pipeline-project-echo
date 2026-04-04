# Copy the Kaniko executor binary from the official image
FROM gcr.io/kaniko-project/executor:latest AS kaniko

FROM ghcr.io/actions/actions-runner:latest

USER root

# ── kubectl ────────────────────────────────────────────────────────────────────
# Version within EKS 1.35 skew policy (cluster ±1 minor)
ARG KUBECTL_VERSION=v1.35.0
RUN curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# ── helm ───────────────────────────────────────────────────────────────────────
ARG HELM_VERSION=v3.16.4
RUN curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
    | tar -xz --strip-components=1 -C /usr/local/bin linux-amd64/helm

# ── Kaniko executor ────────────────────────────────────────────────────────────
# Copied from the official Kaniko image (multi-stage). The pod spec sets
# runAsUser:0 so Kaniko can take filesystem snapshots without privilege.
COPY --from=kaniko /kaniko/executor /usr/local/bin/executor
RUN mkdir -p /kaniko/.docker

# ── aws cli ────────────────────────────────────────────────────────────────────
RUN curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/awscliv2.zip /tmp/aws

# Restore runner user — pod spec will override with runAsUser:0 for Kaniko
USER runner
