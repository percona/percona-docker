Build image

  `docker build -t percona-server Dockerfile`

or

  `docker build -t percona-server Dockerfile`

Tag image
  
  `docker tag <NNNNN> percona/percona-server:8.0`

Push to hub

  `docker push percona/percona-server:8.0`
  
Usage
=====

        vi ./docker-compose.yml
        percona:
          image: percona/percona-server:latest
          name: perconaserver
          environment:
            MYSQL_ROOT_PASSWORD: secret
          ports:
            - "3306"
          volumes:
            # create volumes for use
            - /var/log/mysql
            - /var/lib/mysql
            # bind mount my local my.cnf
            # - $PWD/my.cnf:/etc/my.cnf
          command:
            # Workaround for no my.cnf in image
              - '--user=mysql'
        7) Start the container from cli
            docker-compose up
        8) Check status
            docker-compose ps
