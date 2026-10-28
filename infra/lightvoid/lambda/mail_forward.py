import logging
import os
from email import policy
from email.parser import BytesParser
from email.utils import parseaddr

import boto3

s3 = boto3.client("s3")
ses = boto3.client("ses")

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def body_from_message(msg):
    if msg.is_multipart():
        for prefer in ("text/plain", "text/html"):
            for part in msg.walk():
                if part.get_content_maintype() == "multipart":
                    continue
                disposition = part.get("Content-Disposition") or ""
                if disposition.startswith("attachment"):
                    continue
                if part.get_content_type() == prefer:
                    try:
                        return part.get_content()
                    except Exception:
                        pass
        return "(Could not decode message body.)"
    try:
        return msg.get_content()
    except Exception:
        return "(Could not decode message body.)"


def compose_forward(
    raw,
    *,
    dest_label,
    forward_to,
    from_address,
    envelope_source=None,
):
    """Build a send_email call that passes SPF/DMARC at the recipient."""
    msg = BytesParser(policy=policy.default).parsebytes(raw)
    original_from = msg.get("From") or envelope_source or "unknown"
    _, reply_addr = parseaddr(original_from)
    if not reply_addr and envelope_source:
        reply_addr = envelope_source

    original_subject = msg.get("Subject") or "(no subject)"
    body_text = body_from_message(msg)

    forward_subject = f"[{dest_label}] {original_subject}"
    forward_body = (
        f"New message to {dest_label}\n\n"
        f"From: {original_from}\n"
        f"Subject: {original_subject}\n\n"
        f"---\n\n"
        f"{body_text}\n\n"
        f"---\n"
        f"Forwarded from {dest_label}. Reply goes to the sender.\n"
    )

    request = {
        "Source": f"Lightvoid Support <{from_address}>",
        "Destination": {"ToAddresses": [forward_to]},
        "Message": {
            "Subject": {"Data": forward_subject, "Charset": "UTF-8"},
            "Body": {"Text": {"Data": forward_body, "Charset": "UTF-8"}},
        },
    }
    if reply_addr:
        request["ReplyToAddresses"] = [reply_addr]
    return request


def handler(event, _context):
    forward_to = os.environ["FORWARD_TO"]
    forward_from = os.environ.get("FORWARD_FROM", "support@lightvoid.app")
    mail_bucket = os.environ["MAIL_BUCKET"]
    mail_prefix = os.environ.get("MAIL_PREFIX", "incoming/")

    record = event["Records"][0]["ses"]
    mail = record["mail"]
    message_id = mail["messageId"]
    source = mail.get("source", "unknown")
    destinations = mail.get("destination", [])
    dest_label = ", ".join(destinations) if destinations else "unknown"

    obj = s3.get_object(Bucket=mail_bucket, Key=f"{mail_prefix}{message_id}")
    raw = obj["Body"].read()

    domain = destinations[0].split("@")[-1] if destinations else "lightvoid.app"
    if "@" not in forward_from:
        forward_from = f"support@{domain}"

    send_request = compose_forward(
        raw,
        dest_label=dest_label,
        forward_to=forward_to,
        from_address=forward_from,
        envelope_source=source,
    )

    response = ses.send_email(**send_request)
    logger.info(
        "Forwarded inbound %s (%s) to %s as %s",
        message_id,
        dest_label,
        forward_to,
        response.get("MessageId"),
    )

    return {"status": "ok", "messageId": message_id, "sesMessageId": response.get("MessageId")}
