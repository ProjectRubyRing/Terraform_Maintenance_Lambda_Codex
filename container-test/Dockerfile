FROM public.ecr.aws/lambda/python:3.13

COPY modules/alb_maintenance_lambda/src/ ${LAMBDA_TASK_ROOT}/

CMD ["lambda_function.handler"]
