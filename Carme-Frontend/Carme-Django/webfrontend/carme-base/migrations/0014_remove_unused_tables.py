# Generated by Django 2.2.3 on 2020-04-29 15:45

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('carme', '0013_slurmjobs_update_defaults'),
    ]

    operations = [
        migrations.DeleteModel('UserStatus'),
        migrations.DeleteModel('Messages'),
        migrations.DeleteModel('ImageInstances'),
    ]
