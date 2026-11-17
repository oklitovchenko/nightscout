#!/bin/sh
set -eu

repository=$(CDPATH= cd "$(dirname "$0")/../.." && pwd)
workspace=$(mktemp -d)
trap 'rm -rf "$workspace"' 0
REAL_LN=$(command -v ln)
REAL_MV=$(command -v mv)
export REAL_LN REAL_MV

mkdir "$workspace/bin"
cat > "$workspace/bin/mock" <<'MOCK'
#!/bin/sh
set -eu

name=${0##*/}
[ "$name" != "$FAILED_COMMAND" ] || exit 1
case "$name" in
  ip) echo '169.254.169.254 dev eth0 src 172.31.32.191' ;;
  aws)
    echo '{"API_SECRET":"fixture-secret-1234","MONGO_IMAGE":"mongo:8.0"}'
    ;;
  ln) exec "$REAL_LN" "$@" ;;
  mv)
    rm -f "$3"
    exec "$REAL_MV" "$2" "$3"
    ;;
  curl)
    count=$(cat curl-count 2>/dev/null || echo 0)
    count=$((count + 1))
    echo "$count" > curl-count
    if [ "$((count % 2))" = 1 ]; then printf 401; else printf 200; fi
    ;;
  docker)
    for last; do :; done
    case "$1" in
      container)
        if [ "$last" = nightscout-server-mongo ]; then
          [ -f mongo-created ]
          exit
        fi
        [ "$last" != nightscout-server-app ] || [ -f running-image ]
        ;;
      rm) rm -f running-image ;;
      run)
        case " $* " in
          *' --name nightscout-server-mongo '*)
            printf '%s\n' "$@" | grep -x 'mongo:8.0' > mongo-image-used
            touch mongo-created
            exit
            ;;
        esac
        printf '%s\n' "$last" > running-image
        printf '%s\n' "$last" >> started-images
        ;;
    esac
    ;;
esac
MOCK
chmod +x "$workspace/bin/mock"
for name in ip aws docker ln mv curl; do
  ln -s mock "$workspace/bin/$name"
done

for previous in no yes; do
  for failure in none ln mv; do
    (
      work="$workspace/$previous-$failure"
      mkdir "$work"
      cd "$work"
      if [ "$previous" = yes ]; then
        mkdir legacy
        echo old-image > legacy/images
        echo 'API_SECRET=fixture-secret-1234' > legacy/nightscout.env
        ln -s "$work/legacy" current
        echo old-image > running-image
      fi
      PATH="$workspace/bin:$PATH"
      FAILED_COMMAND=$failure
      bundle="$repository/deploy/ec2"
      container=nightscout-server-app
      image=new-image
      aws_region=eu-central-1
      settings_parameter=/fixture/runtime
      SSM_configVersion=1
      export PATH FAILED_COMMAND bundle container image aws_region
      export settings_parameter SSM_configVersion

      status=0
      sh "$bundle/deploy.sh" > output 2>&1 || status=$?
      [ "$(cat mongo-image-used)" = mongo:8.0 ]
      if [ "$failure" = none ]; then
        [ "$status" = 0 ]
        [ "$(cat current/image)" = new-image ]
        [ "$(cat running-image)" = new-image ]
        [ ! -d legacy ]
      else
        [ "$status" = 1 ]
        set -- release.*
        [ ! -d "$1" ]
        if [ "$previous" = yes ]; then
          [ "$(readlink current)" = "$work/legacy" ]
          [ "$(cat running-image)" = old-image ]
          [ "$(cat started-images)" = "$(printf 'new-image\nold-image')" ]
        else
          [ ! -f running-image ]
          [ ! -L current ]
        fi
      fi
      [ ! -L current.new ]
      echo "Passed deployment: previous=$previous, failed_command=$failure"
    )
  done
done
