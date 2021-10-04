#!/bin/python

import argparse
from datetime import datetime, timedelta

parser = argparse.ArgumentParser(
    description='Advance or reverse the time of a date string and print the result'
)
parser.add_argument('date', type=str, help='Date to modify (YYYYMMDDHH format)')
parser.add_argument('hours', type=int, help='Number of hours to advance or reverse')

args = parser.parse_args()
date, hours = args.date, args.hours

date_begin = datetime.strptime(date, "%Y%m%d%H")
date_end = date_begin + timedelta(hours=hours)
print(date_end.strftime("%Y%m%d%H"))
