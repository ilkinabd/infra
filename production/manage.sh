#!/bin/bash

# Lobbym Infrastructure Management Tool

function show_help() {
    echo "Usage: ./manage.sh [command]"
    echo ""
    echo "Mail Commands:"
    echo "  mail-user-add [user] [domain] [pass]  - Create a new mail account"
    echo "  mail-user-del [user] [domain]         - Delete a mail account"
    echo "  mail-user-pass [user] [domain] [pass] - Change password"
    echo "  mail-admin-add [user] [domain] [pass] - Create a new global admin"
    echo "  mail-domain-add [domain]              - Add a new mail domain"
    echo "  mail-domain-del [domain]              - Delete a mail domain"
    echo "  mail-restart                          - Restart Mailu server containers"
    echo ""
    echo "Database Commands:"
    echo "  db-create [dbname]                    - Create a new Postgres database"
    echo "  db-drop [dbname]                      - Delete a Postgres database"
    echo "  db-user-add [user] [pass]             - Create a new Postgres user"
    echo "  db-user-pass [user] [pass]            - Change Postgres user password"
    echo "  db-user-del [user]                    - Delete a Postgres user"
    echo "  db-list                               - List all databases"
    echo ""
    echo "General Commands:"
    echo "  logs [service]                        - Watch container logs"
    echo "  status                                - Show container status"
    echo "  scraper-restart                       - Restart the scraper container"
    echo "  scraper-rebuild                       - Rebuild and restart the scraper container"
    echo ""
    echo "Highload Service Commands:"
    echo "  cassandra-cqlsh                       - Access Cassandra CQL shell"
    echo "  cassandra-restart                     - Restart Cassandra container"
    echo "  rabbitmq-restart                      - Restart RabbitMQ container"
    echo "  elastic-restart                       - Restart Elasticsearch container"
}

case "$1" in
    # --- MAIL ---
    mail-user-add)
        docker compose exec admin flask mailu user "$2" "$3" "$4"
        ;;
    mail-user-del)
        docker compose exec admin flask mailu user-delete "$2@$3" --really
        ;;
    mail-user-pass)
        docker compose exec admin flask mailu password "$2" "$3" "$4"
        ;;
    mail-admin-add)
        docker compose exec admin flask mailu admin "$2" "$3" "$4"
        ;;
    mail-domain-add)
        docker compose exec admin flask mailu domain "$2"
        ;;
    mail-domain-del)
        docker compose exec admin flask mailu domain-delete "$2"
        ;;
    mail-restart)
        docker compose restart front resolver admin imap smtp antispam webmail
        ;;
    
    # --- DATABASE ---
    db-create)
        docker exec -it lobbym-postgres psql -U postgres -c "CREATE DATABASE $2;"
        ;;
    db-drop)
        docker exec -it lobbym-postgres psql -U postgres -c "DROP DATABASE $2;"
        ;;
    db-user-add)
        docker exec -it lobbym-postgres psql -U postgres -c "CREATE USER $2 WITH PASSWORD '$3';"
        ;;
    db-user-pass)
        docker exec -it lobbym-postgres psql -U postgres -c "ALTER USER $2 WITH PASSWORD '$3';"
        ;;
    db-user-del)
        docker exec -it lobbym-postgres psql -U postgres -c "DROP USER $2;"
        ;;
    db-list)
        docker exec -it lobbym-postgres psql -U postgres -c "\l"
        ;;

    logs)
        docker compose logs -f "$2"
        ;;
    
    status)
        docker compose ps
        ;;

    scraper-restart)
        docker compose restart lobbym-scraper
        ;;

    scraper-rebuild)
        docker compose up -d --build lobbym-scraper
        ;;

    cassandra-cqlsh)
        docker exec -it lobbym-cassandra cqlsh
        ;;

    cassandra-restart)
        docker compose restart cassandra
        ;;

    rabbitmq-restart)
        docker compose restart rabbitmq
        ;;

    elastic-restart)
        docker compose restart elasticsearch kibana
        ;;

    *)
        show_help
        ;;
esac
