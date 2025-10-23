# layers = shared library folder that multiple lambda functions can use
# without layer lambda downloads entire package on cold CreateLogStream
# with layer its cached, faster cold starts 
# FAISS index loading will be faster

data "archive_file" "faiss_layer_zip" {
    type        = "zip"
    source_dir  = "${path.root}/../layers/python"           # takes everyhting in layers/py folder
    output_path = "${path.module}/build/faiss_layer.zip"    # turns it into a zip
}

resource "aws_lambda_layer_version" "faiss_layer {
    layer_name          = "${local.project_name}-faiss-python"
    filename            = data.archive_file.faiss_layer_zip.output_path     # linking zip to dependency
    compatible_runtimes = ["python3.11"]                                    # which py ver can use this layer
    description         = "python dependency"
}