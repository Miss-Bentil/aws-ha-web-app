#!/bin/bash

dnf update -y

dnf install -y nginx

systemctl enable nginx
systemctl start nginx

cat <<'EOF' > /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>AWS HA Web App</title>
</head>
<body>
    <h1>AWS Highly Available Web Application</h1>
    <p>Server is running successfully.</p>
</body>
</html>
EOF

