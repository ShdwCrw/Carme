# Generated by Django 2.0.4 on 2018-10-03 15:40

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('carme', '0001_initial'),
    ]

    operations = [
        migrations.CreateModel(
            name='ImageInstances',
            fields=[
                ('id', models.AutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('instance_name', models.CharField(max_length=128)),
                ('instance_image', models.CharField(max_length=128)),
                ('instance_mounts', models.CharField(max_length=512)),
                ('instance_comment', models.CharField(default='instance description', max_length=1024)),
                ('instance_group', models.CharField(max_length=64)),
                ('instance_owner', models.CharField(max_length=64)),
            ],
        ),
        migrations.AddField(
            model_name='images',
            name='image_owner',
            field=models.CharField(default='admin', max_length=64),
        ),
    ]
