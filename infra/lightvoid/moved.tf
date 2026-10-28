# Renamed philokalia → philoscroll (S3 keys and output names).

moved {
  from = aws_s3_object.philokalia_index
  to   = aws_s3_object.philoscroll_index
}

moved {
  from = aws_s3_object.philokalia_privacy
  to   = aws_s3_object.philoscroll_privacy
}
