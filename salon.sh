#! /bin/bash

PSQL="psql --username=freecodecamp --dbname=salon -X -A -t -q"
DB_DATA=$($PSQL -F '|' -c "SELECT 'S', service_id::text, name FROM services UNION ALL SELECT 'C', phone, name FROM customers ORDER BY 1, 2;")
SERVICE_IDS=()
SERVICE_NAMES=()
declare -A CUSTOMER_NAMES

while IFS='|' read -r record_type record_value record_name; do
  if [[ "$record_type" == "S" ]]; then
    SERVICE_IDS+=("$record_value")
    SERVICE_NAMES+=("$record_name")
  elif [[ "$record_type" == "C" ]]; then
    CUSTOMER_NAMES["$record_value"]="$record_name"
  fi
done <<< "$DB_DATA"

display_services() {
  for index in "${!SERVICE_IDS[@]}"; do
    printf '%s) %s\n' "${SERVICE_IDS[$index]}" "${SERVICE_NAMES[$index]}"
  done
}

printf "\n~~~~~ MY SALON ~~~~~\n\n"
printf "Welcome to My Salon, how can I help you?\n\n"

while true; do
  display_services
  read SERVICE_ID_SELECTED

  SERVICE_NAME=""
  for index in "${!SERVICE_IDS[@]}"; do
    if [[ "${SERVICE_IDS[$index]}" == "$SERVICE_ID_SELECTED" ]]; then
      SERVICE_NAME="${SERVICE_NAMES[$index]}"
      break
    fi
  done

  if [[ -n "$SERVICE_NAME" ]]; then
    break
  fi

  printf "\nI could not find that service. What would you like today?\n"
done

printf "\nWhat's your phone number?\n"
read CUSTOMER_PHONE

CUSTOMER_NAME="${CUSTOMER_NAMES[$CUSTOMER_PHONE]-}"

if [[ -z "$CUSTOMER_NAME" ]]; then
  printf "\nI don't have a record for that phone number, what's your name?\n"
  read CUSTOMER_NAME
fi

printf "\nWhat time would you like your %s, %s?\n" "$SERVICE_NAME" "$CUSTOMER_NAME"
read SERVICE_TIME

$PSQL -v name="$CUSTOMER_NAME" -v phone="$CUSTOMER_PHONE" -v service_id="$SERVICE_ID_SELECTED" -v service_time="$SERVICE_TIME" <<'SQL'
WITH new_customer AS (
  INSERT INTO customers (name, phone)
  VALUES (:'name', :'phone')
  ON CONFLICT (phone) DO NOTHING
  RETURNING customer_id, name
), customer_row AS (
  SELECT customer_id, name FROM new_customer
  UNION ALL
  SELECT customer_id, name FROM customers
  WHERE phone = :'phone' AND NOT EXISTS (SELECT 1 FROM new_customer)
)
INSERT INTO appointments (customer_id, service_id, time)
SELECT customer_id, :'service_id', :'service_time' FROM customer_row;
SQL

printf "\nI have put you down for a %s at %s, %s.\n" "$SERVICE_NAME" "$SERVICE_TIME" "$CUSTOMER_NAME"