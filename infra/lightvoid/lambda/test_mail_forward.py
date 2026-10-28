from email.message import EmailMessage

from mail_forward import compose_forward


def test_compose_forward_rewrites_from_and_subject():
    msg = EmailMessage()
    msg["From"] = "Pat <pat@example.com>"
    msg["To"] = "support@lightvoid.app"
    msg["Subject"] = "Hello"
    msg.set_content("Body text")

    request = compose_forward(
        msg.as_bytes(),
        dest_label="support@lightvoid.app",
        forward_to="owner@gmail.com",
        from_address="support@lightvoid.app",
    )

    assert request["Source"] == "Lightvoid Support <support@lightvoid.app>"
    assert request["Destination"] == {"ToAddresses": ["owner@gmail.com"]}
    assert request["ReplyToAddresses"] == ["pat@example.com"]
    assert request["Message"]["Subject"]["Data"] == "[support@lightvoid.app] Hello"
    assert "Body text" in request["Message"]["Body"]["Text"]["Data"]
    assert "pat@example.com" in request["Message"]["Body"]["Text"]["Data"]
