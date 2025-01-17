# SJay3_infra
SJay3 Infra repository

[![Build Status](https://travis-ci.com/otus-devops-2019-05/SJay3_infra.svg?branch=master)](https://travis-ci.com/otus-devops-2019-05/SJay3_infra)

## Homework 11 (ansible-4)
В данном домашнем задании было сделано:
- Установка Vagrant
- Создание локальной инфраструктуры с помощью vagrant
- Настройка Vagrant для корректного проксирования nginx (*)
- Установка зависимостей для тестирования ролей ansible
- Тестирование роли db
- Использование ролей в плейбуках пакера
- Вынос роли db в отдельный репозиторий (*)

### Установка Vagrant
Vagrant в основном предназначен для локального управления гипервизорами.
[ссылка на скачивание](https://www.vagrantup.com/downloads.html)

Обычно с vagrant используют virtual box, но для его использования необходимо сначала отключить другие гипервизоры (в частности, на windows необходимо выключить hyper-v).

#### Установка на windows
1. Скачиваем дистрибутив
2. Запускаем msi-пакет и следуем инструкциям установщика
3. Перезагружаемся
4. Проверяем, что вагрант установился. Открываем консоль

```
vagrant -v
```

##### Особенности при использовании hyperv
При первом запуске вагрант может сказать, что используется неизвестный провайдер. В этом случае, следует выполнить команду:

```
vagrang up --provider=hyperv
```

!! Провайдер hyperv не умеет работать с сетью. Поэтому при старте машины он спросит, какой виртуальный коммутатор выбрать.
Так же игнорируются все настройки сети, однако, в консоль будет выведен ip адрес машины, которая будет создана.

!! Вагрант по умолчанию подключает smb шару в виртуальную машину. Для Windows требуются права администратора, что бы это сделать, однако, по какой-то причине шара вылетает с ошибкой. Можно отключить создание шары в vagrantfile:

```
config.vm.synced_folder ".", "/vagrant", disabled: true
```

А можно отключить функцию SMB Direct в windows (Панель управления -> Программы и компоненты -> Включение или отключение компонентов Windows) и тогда шара нормально подключится.

#### Установка на Linux (ubuntu)
1. Скачиваем дистрибутив

```shell
wget https://releases.hashicorp.com/vagrant/2.2.5/vagrant_2.2.5_x86_64.deb
```

2. Устанавливаем vagrant

```shell
sudo dpkg -i vagrant_2.2.5_x86_64.deb
```

3. Проверяем установку вагранта

```shell
vagrant -v
```

### Создание локальной инфраструктуры с помощью vagrant
В директории ansible создадим файл Vagrantfile в котором опишем создание нашей инфраструктуры локально.

Установим virtualbox на виртульную машину с ubuntu 18.
Для успешной установки лучше следовать данной [инструкции](http://www.bojankomazec.com/2019/04/how-to-install-virtualbox-on-ubuntu-1804.html), т.к. есть проблемы с EFI и модулями ядра/

Для запуска виртуальных машин, необходимо открыть консоль от имени администратора, после чего в директории ansible выполнить:

```
vagrant up
```

Вагрант проверит наличие образов (box) на локальной машине и скачает, если их нет. После чего попробует запустить виртуальные машины.

Проверить наличие образов можно командой:

```
vagrant box list
```

Проверка статуса виртуаульных машин:

```
vagrant status
```

Подключение к виртуальной машине:

```shell
vagrant ssh <vm_name>
```

#### Провижининг в Vagrant
Вагрант поддерживает провижинеры, в том числе и ансибл. Определение провиженера производится в вагрантфайле внутри конфигурации вм:

```ruby
  config.vm.define "dbserver" do |db|
    db.vm.box = "ubuntu/xenial64"
    db.vm.hostname = "dbserver"
    db.vm.network :private_network, ip: "10.10.10.10"

    db.vm.provision "ansible" do |ansible|
      ansible.playbook = "playbooks/site.yml"
      ansible.groups = {
        "db" => ["dbserver"],
        "db:vars" => {"mongo_bind_ip" => "0.0.0.0"}
      }
      
    end
  end
```

Провижининг происходит автоматически, но можно запустить его вручную, если машины уже запущены:

```shell
vagrant provision <vm_name>
```

Т.к. в ansible мы использовали dynamic inventory, а вагрант генерит инвентори в формате ini, необходимо проверить настройки ansible.cfg, что бы ансибл мог брать инвентори не только из GCP:

```cfg
[inventory]
enable_plugins = gcp_compute, advanced_host_list, host_list, script, auto, yaml, ini

```

#### Доработка ролей ансибла

1. Для того, что бы на всех хостах был установле python версии 2.х, если его нет - создадим плейбук base.yml и включим его в site.yml
2. Удалим плейбук users.yml из site.yml
3. Доработаем роль db добавив таски из плейбука `packer_db.yml` в файл `install_mongo.yml`
4. Вынемем из файла main.yml роли db все таски по отдельным файлам
5. Доработаем роль app добавив установку ruby и разделим main.yml на несколько файлов. Добавим провижининг в вагрант
6. Параметризируем пользователя из под которого будет запускаться приложение: Добавим в роль переменную и параметризируем все файлы, где встречается хардкод appuser

### Настройка Vagrant для корректного проксирования nginx (*)
Для того, что бы nginx нормально проксировал 80 порт на 9292, необходимо в провижининг вагранта добавить extra_vars с переменныеми nginx, которые у нас были сделаны в ansible:

```ruby
      ansible.extra_vars = {
        "deploy_user" => "vagrant",
        "nginx_sites" => {
          "default" => ["listen 80", "server_name \"reddit\"", "location / { proxy_pass http://127.0.0.1:9292; }"]
        }
      }
```

### Установка зависимостей для тестирования ролей ansible
Для локального тестирования ролей, нам потребуются следующие по:
- ansible
- molecule
- Testinfra

Рекомендуется устанавливать данные утилиты через pip в virtualenv среде ([инструкция](https://docs.python-guide.org/dev/virtualenvs/))

Добавим в файл ansible/requrements.txt следующее содержание:

```
molecule>=2.6
testinfra>=1.10
python-vagrant>=0.5.15
```

После чего выполним команду:

```shell
pip install -r requirements.txt
```

Проверим версию молекулы:

```shell
molecule --version
```

### Тестирование роли db
В директории ansible/roles/db выполним команду для создания заготовки для тестов для роли db:

```shell
molecule init scenario --scenario-name default -r db -d vagrant
```
Опция `-d` указывает какой драйвер использовать. Мы используем vagrant.

Отредактируем файл db/molecule/default/tests/test_default.py, вставив в него содержимое:

```python
import os

import testinfra.utils.ansible_runner

testinfra_hosts = testinfra.utils.ansible_runner.AnsibleRunner(
    os.environ['MOLECULE_INVENTORY_FILE']).get_hosts('all')

# check if MongoDB is enabled and running
def test_mongo_running_and_enabled(host):
    mongo = host.service("mongod")
    assert mongo.is_running
    assert mongo.is_enabled

# check if configuration file contains the required line
def test_config_file(host):
    config_file = host.file('/etc/mongod.conf')
    assert config_file.contains('bindIp: 0.0.0.0')
    assert config_file.is_file
```

В файле db/molecule/default/molecule.yml сожержится описание тестовой машины, которую будет создавать молекула.

Создание виртуальной машины через molecule:

```shell
molecule create
```

Посмотреть список машин:

```shell
molecule list
```

Подключиться к машине по ssh:

```shell
molecule login -h <instance_name>
```

molecule генерит плейбук для применения роли в db/molecule/default/playbook.yml. Добавим в плейбук выполнение от рута, а так же переменную `mongo_bind_ip`

Применим плейбук:

```shell
molecule converge
```

Для запуска тестов выполним:

```shell
molecule verify
```

Добавим тест для проверки того, что монга случает порт 27017:

```python
def test_mongo_listening_port(host):
  mongo_socket = host.socket("tcp://0.0.0.0:27017")
  assert mongo_socket.is_listening
```

### Использование ролей в плейбуках пакера
Переделаем плейбуки `packer_db.yml` и `packer_app.yml` Под использование ролей.
Для того, что бы выполнять только таски с тегами из роли, необходимо указать в шаблоне пакера теги. Пример для шаблона db.json:

```json
    "provisioners": [
        {
            "type": "ansible",
            "extra_arguments": ["--tags", "install"],
            "playbook_file": "ansible/playbooks/packer_db.yml"
        }
    ]
```

Т.к. мы запускаем команду `packer build` из корня репозитория, то ансибл не сможет найти роли, т.к. не будет знать, где их искать, а в стандартных директориях нет ни ролей ни файла ansible.cfg. Необходимо передать путь к папке с ролями через переменную окружения `ANSIBLE_ROLES_PATH`. Добавим в провиженер строку:

```
"ansible_env_vars": ["ANSIBLE_ROLES_PATH={{ pwd }}/ansible/roles"]
```

Аналогично сделаем и для плейбука packer_app.yml.

### Вынос роли db в отдельный репозиторий (*)

Создадим отдельный репозиторий и вынесем туда роль. 
В файлах requirements.yml в каждом из окружений добавим:

```yaml
- src: https://github.com/SJay3/ansible-otus-db
  name: db
```

Саму роль удалим из репозитория и добавим её в .gitignore.

Теперь для того, что бы использовать роль, достаточно установить все зависимые роли в окружении:

```shell
ansible-galaxy install -r environments/<env>/requirements.yml
```

#### Подключаем роль к TravisCI для автоматического прогона тестов в GCE

Для начала создадим сервисный аккаунт для тревиса и создадим для него ключ:

```shell
gcloud iam service-accounts keys create ~/travis_gc
p_key.json --iam-account travis-ci@infra-244211.iam.gserviceaccount.com
```

Далее сгенерируем ssh-ключ для подключения к инстансам и добавим его в метадату нашего проекта:

```shell
ssh-keygen -t rsa -f ~/google_compute_engine -C 'travis' -q -N ''
```

Создадим в корне репозитория с ролью файл .travis.yml со следующим содержимым:

```yaml
language: python
python:
  - '3.6'
install:
  - pip install ansible>=2.4.0 molecule apache-libcloud paramiko
script:
  - molecule --debug test
after_script:
  - molecule --debug destroy
```

Теперь подключим наш репозиторий к тревису (через гитхаб) и выполним команды для шифрования данных от GCP:

```shell
travis encrypt GCE_SERVICE_ACCOUNT_EMAIL='travis-ci@infra-244211.iam.gserviceaccount.com' --add --com
travis encrypt GCE_CREDENTIALS_FILE="$(pwd)/credentials.json" --add --com
travis encrypt GCE_PROJECT_ID='infra-244211' --add --community
```

Далее создаем архив с ключем и кредами сервисного аккаунта гугла:

```shell
cd ~
tar cvf secrets.tar credentials.json google_compute_engine
cd -
mv ~/secrets.tar .
```

После логинимся в тревисе и создаем шифрованый файл:

```shell
travis login
travis encrypt-file secrets.tar --add
```

!! Не забыть добавить secrets.tar в .gitignore

Добавим следующие шаги в .travis.yml в секцию before_install:

```yaml
- tar xvf secrets.tar
- mv google_compute_engine /home/travis/.ssh/
- chmod 0600 /home/travis/.ssh/google_compute_engine
```

#### Тестирование через molecule в GCE

Из корня репозитория выполним команду создания нового сценария molecule:

```shell
molecule init scenario --scenario-name gce_test -r <role_name> -d gce
```
где <role_name> - это имя папки в которой находится склонированный репозиторий с ролью

Перенесем тесты вагранта в новый сценарий gce_test: Из `molecule/default/tests/test_default.py` в `molecule/gce_test/tests/test_default.py`.

Аналогичным образом внесем изменения в плейбук gce_test, добавив туда выполнение от рута и переменную `mongo_bind_ip`.

В файле `.travis.yml` в шагах вызова молекулы укажем, что необходимо запускать сценарий gce_test.
Для того, что бы при выполнении опеаций в GCP мог найтись ключ сервисного аккаунта добавим так же в разделе env следующие параметры:

```yaml
env:
  matrix:
    - GCE_CREDENTIALS_FILE="$(pwd)/travis_gcp_key.json"
```

Тем самым мы записываем путь к файлу ключа в переменную окружения.

#### Интеграция со slack

Для интеграции github и slack добавим приложение в github, после чего в слаке выполним команду:

```
/github subscribe SJay3/ansible-otus-db commits:all
```

Для интеграции тревиса со слаком, сначала добавим конфигурацию в slack, перейдем в репозиторий роли и выполним команду:

```shell
travis encrypt "devops-team-otus:<ваш_токен>#dmitriy_usachev" \
--add notifications.slack.rooms --com
```

----
## Homework 10 (ansible-3)
В данном домашнем задании было сделано:
- Создание роли для базы данных
- Создание роли для приложения
- Использование ролей
- Создание окружений
- Работа с community ролями
- Настройка nginx для проксирования
- Работа с ansible vault
- Динамические инвентори в окружениях (*)
- Настройка TravicCI (**)

### Создание роли для базы данных

Создадим файловую структуру роли. Для этого в папке ansible/roles выполним:

```shell
ansible-galaxy init db
```

Из файла `ansible/db.yml` перенесем секцию tasks в `roles/db/tasks/main.yml`.
Аналогично перенесем хендлеры из db.yml в `roles/db/handlers/main.yml`. В файле `defaults/main.yml` определим дефолтные значения переменных `mongo_port` и `mongo_bind_ip`. Скопируем шаблон `mongod.conf.j2` в папку `roles/db/templates`

### Создание роли для приложения

Создадим файловую структуру роли. Для этого в папке ansible/roles выполним:

```shell
ansible-galaxy init app
```

Аналогично, как и для роли db перенесем таски, хендлеры и определим дефолтные переменные в роли app. Так же перенесем шаблоны и файлы.

### Использование ролей

Удалим таски и хендлеры в плейбуках app.yml и db.yml. Вместо них подключим соответствующие роли.

Пример подключения роли:

```yaml
  roles:
    - app
```

## Создание окружений

Создадим директорию environments в каталоге ansible. В директории ansible/environments создадим 2 каталога: stage и prod.

Скопируем в каталоги stage и prod ашду ansible/inventory. (Для использования dynamic inventory, так же скопируем файл inventory.gcp.yml)

Зададим stage, как окружение по умолчанию. Для этого, в файле ansible.cgf изменим строку:

```ini
inventory = ./environments/stage/inventory
```

Для dynamic inventory:

```ini
inventory = ./environments/stage/inventory.gcp.yml
```

Теперь, для того, что бы начать деплой в stage, достаточно написать:

```shell
ansible-playbook deploy.yml
```

Для деплоя в prod, необходимо будет явно указывать файл инвентори:

```shell
ansible-playbook -i ./environments/prod/inventory deploy.yml
```

Далее в каждом окружении создадим папку group_vars где определим переменные для груп хостов. Файл app будет содержать переменные для группы app, файл db - для группы db, а файл all для всех хостов.
В файле all пропишем для stage:

```yaml
env: stage
```
А для prod, соответственно:

```yaml
env: prod
```

Для лучшей организации директории ansible, перенесем все плейбуки в директорию playbooks, а все остальные файлы, не относящиеся к текущей конфигурации в папку old.

## Работа с community ролями
Будем работать с ролью `jdauphant.nginx`.

Добавим файлы requirements.yml в environment/stage и environment/prod

```yaml
- src: jdauphant.nginx
  version: v2.21.1
```

Для установки роли используем команду:

```shell
ansible-galaxy install -r environments/stage/requirements.yml
```

Роль будет установлена в папку `jdauphant.nginx`. Добавим эту папку в .gitignore, что бы внешние роли не коммитились в наш репозиторий.

## Настройка nginx для проксирования

Добавим следущие параметры в файл group_vars/app в stage и prod окружения.

```yaml
nginx_sites:
  default:
    - listen 80
    - server_name "reddit"
    - location / { proxy_pass http://127.0.0.1:9292; }
```

Добавим открытие 80 порта в конфигурацию терраформ для приложения. Для этого в модуле app терраформа найдем ресурс `google_compute_firewall.firewall_puma` найдем строку ports и добавим туда 80 порт:

```
ports = ["9292", "80"]
```

Добавим роль nginx в плейбук app.yml

```yaml
roles:
  - app
  - jdauphant.nginx
```

Теперь применим конфигурацию терраформа, а потом применим плейбук ансибла:

```shell
cd terraform/stage && terraform apply -auto-approve=true
cd ../../ansible && ansible-playbook playbooks/site.yml
```

## Работа с ansible vault
В домашней директории создадим файл ansible_vault.key, в который запишем наш пароль для шифрования/расшифровки секретов.

Мы будем использовать один пароль для 2-х окружений. В реальности, лучше использовать разные пароли для разных окружений.

!! Внимание. В ansible есть баг (на текущий момент до версии 2.8 баг сохраняется), что если в ansible.cfg указан параметр `vault_password_file`, то не получится зашифровать секреты разными ключами, т.к. ансибл не хочет использовать опцию из командной строки вместо опции из конфига.

В окружениях stage и prod создадим файлы credentials.yml содержащие секреты, которые необходимо зашифровать (пароли для пользователей).
Так же создадим плейбук users.yml в котором опишем создание linux-пользователей и подключим в него файл credentials.yml в зависимости от окружения.

В ansible.cfg пропишем путь до нашего ключа:

```ini
vault_password_file = ~/ansible_vault.key
```

Теперь, для того, что бы зашифровать файлы credentials.yml необходимо выполнить команду:

```shell
ansible-vault encrypt environments/stage/credentials.yml
ansible-vault encrypt environments/prod/credentials.yml
```

Для редактирования файлов можно использовать команду:

```shell
ansible-vault edit <file>
```

Для просмотра:

```shell
ansible-vault view <file>
```

Для расшифровки:

```shell
ansible-vault decrypt <file>
```

Так же, добавим вызов плейбуку users.yml в site.yml

## Динамические инвентори в окружениях (*)
В разделе [Создание окружений](#создание-окружений) мы перенесли файлы динамического инвентори в папки с окружениями. Для того, что бы запускать ансибл с динамическим инвентори, необходимо вместо пути к обычному файлу инвентори указывать путь к inventory.gcp.yml.
И для stage и для prod мы используем один и тот же сервисный аккаунт. В реальной жизни стоит использовать разные сервисные аккаунты + разные проекты в GCP, для разграничений разных сред.

## Настройка TravicCI (**)
### Использование trytravis
Для того, что бы тестировать и отлаживать тесты тревиса и не захламлять основной репозиторий с разработкой существует утилиты trytravis. [ссылка на статью](https://medium.com/@Nklya/%D0%BB%D0%BE%D0%BA%D0%B0%D0%BB%D1%8C%D0%BD%D0%BE%D0%B5-%D1%82%D0%B5%D1%81%D1%82%D0%B8%D1%80%D0%BE%D0%B2%D0%B0%D0%BD%D0%B8%D0%B5-%D0%B2-travisci-2b5ef9adb16e)

!! На WSL эта утилита работать не захотела из-за каких-то ошибок с подключением питоновских библиотек

Для установки достаточно выполнить:

```shell
pip install trytravis
```

Так же, необходимо на гитхабе завести тестовый репозиторий в имени которого содержится слово trytravis, подлкючить этот репозиторий к тревису, после чего сказать утилите о том, что его необходимо использовать с помощью команды: 

```shell
trytravis --repo <githubrepo>
```

Теперь можно даже не коммитить в основной репозиторий. Сделав изменения в репе, надо выполнить команду:

```shell
trytravis
```
После чего, утилита автоматически закоммитит и запушит изменения в тестовый репозиторий.

### Создание тестов
Для тестов будем использовать подход otus. Для этого сделаем форк репозтория [otus-homeworks](https://github.com/express42/otus-homeworks) и произведем некоторые изменения.

В корне репозитория создадим папку tests, в которой разместим папку controls (здесь храняться тесты inspec) и файлы inspec.yml (файл-описание тестов) и run.sh (запуск inspec тестов)

В корне репозитоия так же находится файл run.sh основное предназначение которого - это запуск докер-контейнера и вызов файла run.sh из папки tests.

Внутри папки tests/controls находятся файлы для проверки синтаксиса файлов terraform, packer и ansible

Так же удалим из репозитория все лишнее и запушим все в мастер ветку.

[репозиторий с тестами](https://github.com/SJay3/otus-homeworks)

Теперь в нашем основном репозитории infra поменяем файл .travis.yml что бы секция before_install выглядела следующим образом:

```yaml
before_install:
  - curl https://raw.githubusercontent.com/express42/otus-homeworks/2019-05/run.sh | bash
  - curl https://raw.githubusercontent.com/SJay3/otus-homeworks/master/run.sh | bash

```

----
## Homework 9 (ansible-2)
В данном домашнем задании было сделано:
- Создание плейбука для настройки и деплоя приложения и БД
- Создание одного плейбука для нескольких сценариев
- Создание нескольких плейбуков
- Использование готовых Dynamic Inventory (*)
- Провижининг в Packer

### Создание плейбука для настройки и деплоя приложения и БД
В этом способе у нас один плейбук и мы запускаем его на разных хостах с помощью опций `--limit`, а так же ограничиваем исполнение через `--tags`
#### Настройка базы данных modgoDB
Для настройки базы mongoDB необходимо изменить конфигурацию, расположенную в файле `/etc/mongod.conf`, прописав порт для подключения к базе, а так же ip адрес, который будет слушать база для приема подключений.
Для этого создадим шаблон `templates/mongod.conf.j2` в котором через переменные зададим соответствующие параметры. В плейбуке, для того, что бы на сервер был скопирован уже отрендеренный файл конфигурации будем использовать модуль `template`.

После успешного изменения файла конфигурации, необходимо перезапустить сервис mondod. Для этого определим handler с использованием модуля service (этот модуль может управлять, как сервисами systemd, так и более старыми: upstart и SysV)

Для настройки базы необходимо запустить следующую команду:

```shell
ansible-playbook reddit_app.yml --limit db --tags db-tag
```

#### Настройка инстанса приложения
Для настройки приложения, нам необходимо скопировать файл puma.service на сервер приложения. Т.к. файл не шаблонизирован, то мы его просто скопируем с помощью модуля `copy`. 
В файле сервиса мы используем директиву `Environment`, что бы из файла загрузить переменные окружения перед запуском сервиса. Это необходимо, для передачи приложению адреса базы данных через переменную окружения DATABASE_URL. Создадим шаблон `db_config.j2` в которой с помощью переменной определим адрес БД. В плейбуке с помощью модуля template отреднерим шаблон в файл и скопируем на сервер приложения. 
Так же, необходимо добавить сервис puma.service в автозагруку. Сделаем это через модуль `systemd`. С помощью этого же модуля создадим хендлер, который будет вызываться после копирования файла сервиса.

Для настройки приложения необходимо запустить следующую команду:

```shell
ansible-playbook reddit_app.yml --limit app --tags app-tag
```

#### Деплой приложения
В образе, который мы используем, приложение уже установлено. Однако, для того, что бы у нас всегда была последняя версия нашего приложения и зависимостей ruby, добавим деплой с помощью модулей `git` и `bundle`

Для деплоя последней версии приложения необходимо запустить следующую команду:

```shell
ansible-playbook reddit_app.yml --limit app --tags deploy-tag
```

### Создание одного плейбука для нескольких сценариев
Мы разбиваем плейбук на несколько сценариев (plays) для более удобного управления несколькими хостами. Для этого создадим отдельный плейбук reddit_app2.yml. Запуск плейбука на разные сценарии будет выполнятся только с помощью параметра `--tags`
#### Сценарий для mongoDB
Перенесем таски для монги в новый плейбук, выделя их в отдельный плей. При этом вынесем выполнение от рута, теги на уровень плея, а хосты ограничим только выполнением на группе db

Выполнение сценария производится командой:

```shell
ansible-playbook reddit_app2.yml --tags db-tag
```

#### Сценарий для App
Перенесем таски с тегом app-tag в отдельный плей в файле reddit_app2.yml. Вынесем выполнение от рута и теги на уровень плея, а так же ограничим выполнение только на хостах группы app.
Так же, в таске копирования конфигурации БД принудительно укажем владельца и группу у копируемого файла

Выполнение сценария производится командой:

```shell
ansible-playbook reddit_app2.yml --tags app-tag
```

#### Сценарий для деплоя приложения
Аналогичным образом, как и в предыдущих случаях перенесем деплой приложения отдельным плеем.

Выполнение сценария производится командой:

```shell
ansible-playbook reddit_app2.yml --tags deploy-tag
```

### Создание нескольких плейбуков
Разделим наш последний плейбук на несколько в соответствии со сценариями: app.yml, db.yml и deploy.yml. Создадим так же плейбук site.yml в который импортируем 3 созданных плейбука

Запуск сценария осуществляется:

```shell
ansible-playbook site.yml
```

### Использование готовых Dynamic Inventory (*)
Для генерации динамического инвентори будем использовать встроенный в ансибл плагин `gce_compute` (вместо gce.py). [Подробней](https://docs.ansible.com/ansible/latest/scenario_guides/guide_gce.html) и [еще](http://matthieure.me/2018/12/31/ansible_inventory_plugin.html)

Полный список инвентори плагинов можно посмотреть командой:

```shell
ansible-doc -t inventory -l
```

#### Подготовка
Для использования плагина, необходимо для начала установить библиотеки питона:

```shell
pip install requests
pip install google-auth
```

#### Сервисный аккаунт google
Далее необходимо сгенерировать и скачать json с реквизитами специального сервисного аккаунта. [ссылка](https://cloud.google.com/iam/docs/creating-managing-service-account-keys)

Через меню IAM&admin -> Service accounts создадим сервисный акканут ansible с ролью Compute Viewer.
Далее с помощью утилиты gcloud создадим ключ сервисного аккаунта, который сразу же сохраним в файле `ansible_gcp_key.json`:

```shell
gcloud iam service-accounts keys create ~/ansible_gcp_key.json --iam-account ansible@infra-244211.iam.gserviceaccount.com
```

#### Подключение плагина
Для начала в `ansible.cfg` включим плагин:

```
[inventory]
enable_plagins = gcp_compute
```

Далее создадим файл, оканчивающийся на .gcp.yml (inventory.gcp.yml) и путь к этому файлу так же пропишем в `ansible.cfg`

Минимальное содержание файла inventory.gcp.yml:

```yaml
plugin: gcp_compute
projects:
  - infra-244211
regions:
  - europe-west1
filters: []
auth_kind: serviceaccount
service_account_file: ~/ansible_gcp_key.json
```

Для проверки, что плагин работает используем команду:

```shell
ansible-inventory --graph
```

Для группировки можно использовать groups:

```yaml
groups:
  app: "'app' in name"
  db: "'-db' in name"
```

### Провижининг в Packer
Создадим 2 плейбука: 
- packer_app.yml
- packer_db.yml

В первом опишем установку ruby и bundler с использованием модуля apt. Во втором опишем установку mongodb используя модули apt, apt_key, apt_repository и systemd

Добавим использование ansible в провиженеры пакера в шаблонах app.json и db.json

```
    "provisioners": [
        {
            "type": "ansible",
            "playbook_file": "ansible/packer_app.yml"
        }
    ]
```

```
    "provisioners": [
        {
            "type": "ansible",
            "playbook_file": "ansible/packer_db.yml"
        }
    ]
```

----
## Homework 8 (ansible-1)
В данном домашнем задании было сделано:
- Установка Ansible
- Конфигурация Ansible
- Написание простого плейбука
- Создание динамического инвентори в формате JSON

### Установка Ansible (для ubuntu 16 и 18)
Подходит для установки на WSL
Для начала необходимо установить python 2.7

```shell
sudo apt update
sudo apt install python
```

Ansible можно устатновить через пакетный менеджер ОС (apt) или пакетный менеджер питона (pip)
[Официальный мануал по установке](https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html)

#### Установка через apt

```shell
$ sudo apt update
$ sudo apt install software-properties-common
$ sudo apt-add-repository --yes --update ppa:ansible/ansible
$ sudo apt install ansible
```

#### Установка через pip

```shell
sudo apt update
sudo apt install python-pip
pip install --user ansible
```

### Конфигурация Ansible
Для работы ansible, необходимо создать inventory файл, в котором будут указаны хосты, которыми будет управлять ансибл. Для того, что бы у каждого хоста не указывать пользователя, под которым подключается ансибл и ключ, занесем эту информацию в файл ansible.cfg в директории ansible. Это локальный файл конфигурации:

```
[defaults]
inventory = ./inventory
remote_user = appuser
private_key_file = ~/.ssh/appuser
host_key_checking = False
retry_files_enabled = False
```

!! Для работы на WSL необходимо сделать дополнительную настройку wsl-системы в части прав на автоматически монтируемые директории. Для этого создадим или отредактируем файл /etc/wsl.conf:

```
[automount]
enabled = true
mountFsTab = false
root = /mnt/
options = "metadata,umask=22,fmask=11"

[network]
generateHosts = true
generateResolvConf = true
```

Это необходимо, т.к. ансибл не читает файл ansible.cfg если он находится в директории с правами на запись для всех.

#### inventory файл
Обычно в ansible используется инвентори файл в формате ini. Но с версии 2.4 появилась возможность исполльзовать инвентори в формате yml. [документация по инвентори](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html)

### Написание простого плейбука
После создания инвентори файла, напишем простой плейбук для клонирования репозитория на машину app и назовем его clone.yml.

Для выполнения плейбука выполним команду:

```shell
ansible-playbook clone.yml
```

Если на сервере уже был склонирован репозиторий в папку `~/reddit`, то статус выполнения таски `clone repo` будет `ok`. Но, если репозитория там не будет, или мы к прмеру удалим его командой

```shell
ansible app -m command -a 'rm -rf ~/reddit'
```

а потом повторно выполним плейбук, то статус таски `clone repo` будет `changed`. Это означает, что ансибл выполнил данную задачу и она повлекла изменения на сервере. Т.е. Состояние сервера отличалось от описанного в плейбуке.

### Создание динамического инвентори в формате JSON

В ансибл в качестве файла инвентори можно указывать скрипт, который должен возвращать JSON в определенном формате (формат немного отличается от формата для статического инвентори). Так же, скрип должен уметь принимать аргументы: `--list` и `--host`. Это обязательные условия, помимо необходимой структуры JSON. Подробней про написание скрипта и создание параметров в статье на [медиум](https://medium.com/@Nklya/%D0%B4%D0%B8%D0%BD%D0%B0%D0%BC%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%BE%D0%B5-%D0%B8%D0%BD%D0%B2%D0%B5%D0%BD%D1%82%D0%BE%D1%80%D0%B8-%D0%B2-ansible-9ee880d540d6)
[Пример написания скрипта](https://www.jeffgeerling.com/blog/creating-custom-dynamic-inventories-ansible)

Согласно правилам напишем скрипт на python (dynamic_inventory.py) со следующей логикой:
- Скрипт принимает аргументы `--list` и `--host`
- При указании аргумента `--host` выводится пустая секция `_meta`
- При указании `--list` выводится сформированный JSON
- В json хардкод на 2 группы хостов: app и db
- Скрипт должен подключаться к GCP бакету, в котором хранится состояние примененной конфигурации терраформа
- из конфигурации должны считываться ресурсы `google_compute_instance`: параметр `name` и `network_interface.0.access_config.0.nat_ip`
- По параметру `name` должна определяться к какой группе относится ресурс: reddit-app-1 относится к группу app, а reddit-db к группе db
- Так же скрипт должен генерить файл inventory.json, куда должен записывать json, сформированый при вызове скрипта с параметром `--list`

Для использования динамического инвентори по умолчанию, небходимо в ansible.cfg прописать путь к скрипту.

Для работы скрипта, необходима библиотека для python google-cloud-storage. Её можно установить вручную:

```shell
pip install google-cloud-storage
```


#### Отличия динамического json от статического
Главное отличие json генерируемого скриптом, от статического json в налчии секции `_meta` с информацией о всех переменных хостов.
Так же, в динамическом json не получится использовать алиасы для хостов, т.к. хосты необходимо передавать массивом, а не объектом.

----
## Homework 7 (terraform-2)
В данном домашнем задании было сделано:
- Импорт существующего правила firewall
- Структуризация ресурсов
- Созданием модулей
- Параметризация модуля vpc
- Создание окружений stage и prod
- Работа с реестром модулей
- Хранение стейт-файлов в удаленном бекэнде (*)
- Добавление provisioner в модули приложения (**)

### Импорт существующего правила firewall
По заданию, мы должны создать правило для фаервола, разрешающее подключение по ssh. Но в GCP оно уже создано по умолчанию. Однако, что бы мы могли управлять этим правилось через terraform, его нужно описать в main.tf, после чего выполнить импорт, что бы терраформ знал, что такое правило уже существует в GCP

```shell
terraform import google_compute_firewall.firewall_ssh default-allow-ssh
```

### Структуризация ресурсов
Вынесем БД на отдельный инстанс ВМ. Для этого, для начала создадим 2 разных образа с помощью packer: db.json и app.json.

Далее разобьем файл main.tf на несколько конфигов, аналогично, как мы сделали с конфигурацией для packer. Создадим файлы app.tf с описанием приложения и db.tf с описанием базы. Так же, создадим файл vpc.tf, куда вынесем правило фаервола, которое применимо для всех инстансов (default-allow-ssh)

Перед тем, как создавать образы, необходимо проверить, что в GCP создано правило default-allow-ssh. Если его нет (возможно мы применили terraform destroy), то необходимо его создать, либо вручную, либо с помощью терраформа:

```shell
terraform apply -target=google_compute_firewall.firewall_ssh
```

После того, как разобьем файлы на несколько конфигов, сделаем сначала 2 новых образа:

```shell
packer build -var-file=variables.json app.json
packer build -var-file=variables.json db.json
```

А потом развернем терраформом инфраструктуру:

```shell
terraform plan
terraform apply
```

### Создание модулей
Перед тем, как создавать модули, уничтожим текущую инфраструктуру:

```shell
terraform destroy
```

В дирректории terraform создадим папку modules. Создадим модуль для базы данных и для приложения.

#### Модуль для базы
Создадим папку db внутри папки modules. Внутри создадим 3 файла: main.tf, variables.tf и outputs.tf. В файл main.tf скопируем содержимое ранее созданного файла db.tf. В файле variables.tf опишем используемые переменные для модуля с базой: `public_key_path`, `zone` и `db_disk_image`

#### Модель для приложения
По аналогии с базой, создадим папку app внутри директории modules с 3-мя файлами main.tf, variables.tf и outputs.tf. В файл main.tf скопируем содержимое из файла app.tf. В файле variables.tf опишем используемые переменные для приложения: `public_key_path`, `zone`, `app_disk_image` и `instance_count`

#### Использование модулей
Перед тем, как использовать модули, необходимо удалить из папки terraform ранее созданные файлы db.tf и app.tf, а в файле main.tf прописать использование модулей:

```
module "app" {
  source = "modules/app"
  public_key_path = "${var.public_key_path}"
  zone = "${var.zone}"
  app_disk_image = "${var.app_disk_image}"
  instance_count = "${var.instance_count}"
}

module "db" {
  source = "modules/db"
  public_key_path = "${var.public_key_path}"
  zone = "${var.zone}"
  db_disk_image = "${var.db_disk_image}"
}
```

#### Модуль vpc
Аналогичным образом сделаем модуль для vpc. Создадим файл main.tf в папке vpc внутри папки modules. Создавать файлы outputs.tf и variables.tf пока нет необходимости, т.к. мы не получаем никаких входных и выходных данных. Добавим так же использование этого модуля в основной main.tf

### Параметризация модуля vpc
Для параметризации модуля vpc вынесем директиву source_ranges в отдельную переменную. После этого, мы сможем указывать source_ranges для ssh как параметр к модулю

### Создание окружений stage и prod
Для создания разных окружений, создадим папки stage и prod внутри папки terraform, скопируем в них файлы main.tf, variables.tf, outputs.tf, а так же terraform.tfvars и terraform.tfvars.example

В файлах main.tf поменяем пути к модулям. Так же вынесем значение переменной source_ranges в terraform.tfvars, и для stage зададим `0.0.0.0/0` а для prod свой ip-адрес.
Удалим файлы main.tf, variables.tf, outputs.tf и terraform.tfvars из корневой папки terraform, т.к. они больше не нужны.

### Работа с реестром модулей
Модули можно брать из [реестра терраформа](https://registry.terraform.io/).
Воспользуемся модулем [storage-bucket](https://registry.terraform.io/modules/SweetOps/storage-bucket/google/0.2.0) для создания бакетов в GCP. Создадим файл storage-bucket.tf в котром опишем провайдера и используемый модуль. Так же создадим файл variables.tf в котором опишем переменные для проекта и региона, а в файле terravorm.tfvars зададим значения для этих переменных.

Важно! Имена бакетов должны быть уникальны в пределах региона!

### Хранение стейт-файлов в удаленном бекэнде (*)

С помощью конфигурации storage-bucket создадим 2 бакета для stage и prod
Создадим файлы backend.tf для stage и prod, где опишем конфигурации бекэндов:

```
#stage terraform backend
terraform {
  backend "gcs" {
    bucket = "sjay3-terraform-stage"
    prefix = "reddit-stage"
  }
}

```

Командой `terraform init` инициализзируем бекенды и проверим, что файлы tfstate перенеслись в бакеты.

Теперь, если перенести конфигурацию с настроенным бекэндом в любое другое место, террафоорм будет искать бекэнд в бакетах гугла.
При запуске терраформа (`terraform apply`) в бакете создается файл блокировки `.tflock`. Этот файл существует, пока идет применение конфигурации, после чего удаляется. Если запустить одновременно 2 применения одной и той же конфигурации, то та, что была запущена позжеж упадет с ошибок о том, что состояние заблокировано.

### Добавление provisioner в модули приложения (**)

Для того, что бы связать 2 инстанса app и db, первым делом, необходимо, что бы база данных mongo могла принимать подключения не только с локалхоста. Для этого, в модуле db создадим папку files, куда скопируем файл с параметрами монги, находящийся в `/etc/mongod.conf`. В нем найдем параметр `bindIp` и заменим значением в нем на 0.0.0.0.
Теперь в main.tf модуля db добавим провиженеры:

Для копирования файла с параметрами во временную директорию:

```
  provisioner "file" {
    source = "${path.module}/files/mongod.conf"
    destination = "/tmp/mongod.conf"
  }
```

Для перемещения конфига в целевое местоположение и рестарта базы:

```
  provisioner "remote-exec" {
    inline = ["sudo mv /tmp/mongod.conf /etc/mongod.conf", "sudo systemctl restart mongod.service"]
  }
}
```

Так же, в outputs.tf добавим новую переменную, для захвата внутреннего ip адреса машины с базой:

```
output "db_internal_ip" {
  value = "${google_compute_instance.db.network_interface.0.network_ip}"
}
```

Теперь займемся настройкой модуля app, для деплоя приложения и связи его с БД. Для начала добавим новую переменную, `db_hostname` со значением по умолчанию localhost. Далее подготовим файлы для депроя и управления приложением через systemd: deploy.sh и puma.service. Поскольку подключение приложения к БД осуществляется при запуске через переменную окружения `DATABASE_URL` добавим в файл puma.service в секцию `[service]` следующую строку:

```
Environment=DATABASE_URL=${db_hostname}
```
 
Поскольку файл у нас содержит переменную, необходимо содержимое файла зарендерить перед тем, как передавать на сервер. Для этого используем специального провайдера `template_file`, который определяется с помощью data source:

```
data "template_file" "puma_service" {
  template = "${file("${path.module}/files/puma.service")}"
  vars = {
    db_hostname = "${var.db_hostname}"
  }
}
```

Теперь займемся провиженерами. Сначала скопируем зарендеренный файл на ВМ:

```
  provisioner "file" {
    content      = "${data.template_file.puma_service.rendered}"
    destination = "/tmp/puma.service"
  }
```

После чего выполним провиженер, который запускает скрипт deploy.sh

В проектах stage и prod изменим main.tf добавив в подключение модуля app новое значение перемменной:

```
db_hostname = "${module.db.db_internal_ip}"
```

Так же, можно добавить в outputs вывод этой переменной.

----
## Homework 6 (terraform-1)
В данном домашнем задании было сделано:
- Установка terraform
- Организация структуры проекта в terraform
- Запуск проекта и основные команды
- Работа с ssh-ключами и пользователями в terraform (*)
- Созданние нескольких ресурсов и балансирование нагрузки (**)

### Установка terraform
Для установки terraform необходимо скачать дистрибутив с оффициального сайта [terraform](https://www.terraform.io/downloads.html). Т.к. домашнии задания адаптированы для версии 0.11.11, а последняя версия > 12, то для скачивания старой версии терраформа, необходимо найти её по следующей [ссылке](https://releases.hashicorp.com/terraform/0.11.11/). Скачанный архив необходимо распаковать в папку `~/terraform/`.
Далее, необходимо добавить путь к утилите packer в PATH. В `~/.bashrc` необходимо добавить строку в конец файла:

```shell
export PATH=$PATH:~/terraform/
```

Применим изменения, что бы не перелогиниваться с новой сессией:

```shell
source ~/.bashrc
```

### Структура проекта в terraform
При запуске терраформа, он будет считывать все файлы `.tf` из текущей директории. Структура проекта состоит из следующих файлов:
- main.tf
- variables.tf
- outputs.tf
- variables.tfvars

#### main.tf
Основной файл проекта. В нем указывается версия terraform, на которой будет работать проект, провайдер ресурсов, сами ресурсы. Внутри ресурсах могут быть указаны провижионеры. 

[Ссылка на документацию](https://www.terraform.io/docs/cli-index.html): Провизионеры, ресурсы, провайдеры и т.д.

#### variables.tf
В данном файле инициализируются переменные. У них указывается тип, описание, и значение по умолчанию (не обязательно).
Пример:

```
variable "region" {
  type        = "string"
  description = "region"
  default     = "europe-west1"
}
```

#### outputs.tf
В этом файле указываются выходные переменных, которые терраформ получает во время выполнения стейта. Эти переменные можно потом использовать для различных систем конфигурации.

#### variables.tfvars
Если в папке с проектом есть файл variables.tfvars то он тоже считывается автоматически терраформом. В противном случае, необходимо запускать терраформ с ключем `-var-file`, куда передавать путь к файлу с переменными.

В этом файле содержатся значения переменных, которые были определены в файле variables.tf.
Переменные указываются в формате ключ=значение.

### Запукс проекта и основные команды
Для запуска dry-run, необходимо выполнить команду

```shell
terraform plan
```
Терраформ покажет планируемые изменения, которые произойдут в инфраструктуре.

Для применения конфигурации, необходимо выполнить команду:

```shell
terraform apply
```
Терраформ покажет изменения и запросит подтверждение выполнения стейта. Для того, что бы терраформ не запрашивал подтверждение, а начинал выполнять стейт сам, необходимо запускать терраформ со специальным ключем:

```shell
terraform apply -auto-approve=true
```

При работе терраформ создает специальные файлы с расширением `.tfstate`. В них он хранит состояние применения конфигурации. Важно, что терраформ смотрит состояние только по этим файлам и не подключается к провайдеру, поэтому при использовании терраформа не следует править конфигурацию руками. Только через код терраформа.

Для просмотра и поиска по tfstate файлам, можно использовать команду:

```shell
terraform show
```

Если выходные переменные были добавлены после применения стейта, то занести в них информацию можно с помощью команды:

```shell
terraform refresh
```

Посмотреть значения выходных переменных можно командой:

```shell
terraform output
```

Для того, что бы терраформ заного пересоздал ресурс необходимо использовать команду:

```shell
terraform taint <тип_ресурса.имя_ресурса>
```
Это может потребоваться, к прирмеру, когда мы изменили провижионеры в ресурсе или добавили новых провижионеров, т.к. они запускаются только при создании ресурса или при удалении.

Для удаления ресурса используется следующая команда:

```shell
terraform destroy
```

### Работа с ssh-ключами и пользователями в terraform (*)

Для добавления ssh-ключа в метадату проекта, необходимо использовать отдельный ресурс `google_compute_project_metadata_item`. Этот ресурс добавляет 1 единицу метаданных в проект. Но для того, что бы можно было добавиь ssh ключ, необходимо указать **ssh-keys** в качестве значения у параметра **key**.

```
resource "google_compute_project_metadata_item" "appuser1" {
  key = "ssh-keys"
  value = "appuser1:${file(var.public_key_path)}"
  project = "${var.project}"
}
```

Для добавления сразу нескольких метаданных или нескольких ssh ключей, необходимо использовать другой ресурс: `google_compute_project_metadata`. Пример добавления нескольких ключей:

```
resource "google_compute_project_metadata" "many_keys" {
  project = "${var.project}"
  metadata = {
    ssh-keys = "appuser2:${file(var.public_key_path)} \nappuser3:${file(var.public_key_path)}"
  }
}
```

Нельзя использовать сразу 2 этих ресурса, т.к. терраформ будет затирать данные, добавленные одним из ресурсов. Так же, добавленные через веб-интерфейс ключи тоже будут удалены, если терраформ управляет метадатой.

### Созданние нескольких ресурсов и балансирование нагрузки (**)
#### Балансировщик
Создадим файл lb.tf в котором опишем настройки встроенного балансировщика нагрузки в GCP
Для того, чтобы создать балансировщик нагрузки в GCP необходимо:
- Создать группу инстансов и добавить необходимые инстансы в неё
- Создать хелс-чек, для проверки работоспособности инстансов
- Создать бекенд сервис, ссылающийся на группу
- Создать urlmap, у которого указать дефолтный инстанс
- Создать target proxy, ссылающийся на urlmap
- Создать forwarding rule, ссылающийся на target proxy

##### Группа инстансов
Создается через ресурс **google_compute_instance_group**. Необходимо указать имя, зону, а так же ссылку на каждый инстанс, который будет находиться в группе.
Так же, директивой `named_port`, необходимо указать порт и имя порта (по имени другие ресурсы будут обращаться к порту)
##### Health check
Health cheacks нужны для того, что бы проверять, работает ли сервис или нет.
Существует несколько видов хелс чеков (разные ресурсы): для http и для https. В хелс чеке указывается request_path и порт, по которому будут отправляться запросы к сервису.
##### Backend service
Это часть балансировщика, которая связывает его и группу инстансов. Здесь указывается имя порта (которое мы определили в группе инстансов), протокол, ссылка на группу инстансов и health check. Хелс чек возможно указать только один. Если необходимо использовать несколько хелс чеков или несколько разных портов, то надо создавать несколько бекенд сервисов.
##### Urlmap
Urlmap - это ядро балансирощика. Имя, определенное в этом ресурсе будет видно в веб-интерфейсе. Urlmap - это карта перенаправления url (аналог location в nginx).
Необходимо обязательно указывать дефолтовый backend (`default_service`).
##### Target proxy
Проксирует входищие соединения с форвардера на urlmap. существует несколько прокси. В том числе http и https (это отдельные ресурсы)
##### Forwarding rule
Описывает правила форвардинга. Это лицо балансировщика, тут указывается порт для входящих соединений и ссылка на прокси.

#### Внешний адрес балансировщика
Для определения внешнего адреса балансировщика, добавим в файл outputs.tf следующую переменную:

```
output "lb_external_ip" {
  value = "${google_compute_global_forwarding_rule.reddit-forward.ip_address}"
}
```

#### Добавление второго инстанса в балансировщик
Скопируем ресурс `google_compute_instance.app` и поменяем название ресурса на app2, а так же имя (name) на eddit-app2.
Добавим в outputs.tf новую переменную, определяющую ip адрес второго инстанса. Не забудем в файле lb.tf добавить новый инстанс в группу.

Такой подход добавления нового инстанса в группу не слишком удобен:
- Слишком много кода надо копировать
- Необходимо изменить имя ресурса и имя самого инстанса
- Необходимо добавить новый инстанс в группу инстансов.
- Необходимо добавить новую переменную для нового инстанса

#### Использование count для множественного создания инстансов
Завведем переменную instance_count с дефолтным значением 1. В main.tf добавим директиву count в ресурс `google_compute_instance.app`. В качестве имени инстанса укажем `reddit-app-${count.index + 1}`
Для того, что бы ссылаться на наши инстансы необходимо использовать немного другой синтаксис. К примеру, для указания инстансов в группе, следует использовать `${google_compute_instance.app.*.self_link}`, где вместо `*` можно указать номер инстанса. Номера начинаются с 0. Можно так же применять различные фильтры, для более точного указания инстансов.

----
## Homework 5 (packer-base)
В данном домашнем задании было сделано:
- Установка packer
- Предоставление доступа к GCP через ADC
- Создание образа ВМ через packer (fry подход)
- Создание полного образа ВМ (bake подход) (*)
- Создание скрипта создания ВМ из собранного образа (*)

### Установка packer
Для установки packer, необходимо скачать дистрибутив по [ссылке](https://www.packer.io/downloads.html), распаковать архив в папку `~/packer/`.
Далее, необходимо добавить путь к утилите packer в PATH. В `~/.bashrc` необходимо добавить строку в конец файла:

```shell
export PATH=$PATH:~/packer/
```

Применим изменения, что бы не перелогиниваться с новой сессией:

```shell
source ~/.bashrc
```

### Предоставление доступа к GCP через ADC
Для того, что бы packer мог подключаться к google cloud необходимо ему разрешить доступ. Это можно сделать через Application Default Credentials (ADC). Это позволяет приложениям работать с АПИ гугла используя credentals пользователя авторизованного через gcloud.

Выполним команду:

```shell
gcloud auth application-default login
```

### Создание образа ВМ через packer
Для работы через packer создадим файл шаблона ubuntu16.json, в котором будет описана конфигурация создаваемого нами образа.
Основные секции этого файла:
- variables - указываются переменные, которые имеют значения по умолчанию и не обязательны.
- builders - секция сборки образа. Для GCP тут указываются параметры временной виртуальной машины, на основе которой будет создан наш образ, а так же имя и семейство нашего образа
- provisioners - секция в которой указываются, что необходимо выполнить после запуска виртуальной машины, к примеру, установить необходимый софт.

Так же, создадим отдельный файл variables.json, в котором переопределим дефалтовые переменные, а так же обязательные переменные, которые нельзя определять в ubuntu16.json.
Поскольку данный файл нельзя пушить в репозиторий, т.к. он может содержать секреты, то создадим файл varibles.json.example, в котором опишем пример используемых параметров.

Для проверки корретности файла шаблона можно использовать:

```shell
packer validate ubuntu16.json
```
Что бы пакер зарезолвил все переменные, необходимо использовать синтаксис:

```shell
packer validate -var-file=variables.json ubuntu16.json
```

Если валидация прошла успешно, то запустить сборку можно командой:

```shell
packer build -var-file=variables.json ubuntu16.json
```

### Создание полного образа ВМ (bake подход) (*)
Для практики подхода immutable infrastructure, необходимо использовать подход к созданию образа именуемый bake.
Для этого был создан файл immutable.json, из которого packer собрал полный образ с уже установленным и добавленным в автозапуск приложением.
В качестве базового образа был выбран образ reddit-base, созданный на прошлом шаге. После скачивания git-репозитория и установки приложения, выполняется копирование подготовленного systemd unit во временную директорию, после чего юнит перемещается в целевую директорию и активируется автозапуск при загрузке.

Юнит запускает приложение из-под пользователя, поэтому, если используется другой пользователь, то его + пути к скачанному репозиторию необходимо поменять, перед пересборкой образа.

### Создание скрипта создания ВМ из собранного образа (*)

Для более быстрого создания и запуска ВМ из образа reddit-full был написан скрипт create-reddit-vm.sh, помещенный в директорию config-scripts.
Сам скрипт:

```shell
#!/bin/bash
#create reddit vm
gcloud compute instances create reddit-app\
  --boot-disk-size=10GB \
  --image-family reddit-full \
  --machine-type=g1-small \
  --tags puma-server \
  --restart-on-failure
  
```

----
## Homework 4 (cloud-app)
В данном домашнем задании было сделано:
- Установка gcloud
- Установка тестового приложения с настройкой инфраструктуры
- Создание bash-скриптов для установки приложения и настройки инфраструктуры
- Создание startup script
- Создание правила фаервола с помощью gcloud


### Ревизиты для проверки

    testapp_IP = 35.228.222.184
    testapp_port = 9292

### Установка gcloud
[Инструкция по установке](https://cloud.google.com/sdk/docs/#deb)

### Создание ВМ через gcloud

```shell
gcloud compute instances create reddit-app\
  --boot-disk-size=10GB \
  --image-family ubuntu-1604-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=g1-small \
  --tags puma-server \
  --restart-on-failure
```

### Деплой приложения
Выполняем на машине reddit-app
#### Установка ruby

```shell
sudo apt update
sudo apt install -y ruby-full ruby-bundler build-essential
```

Проверка ruby и bundler

```shell
ruby -v
bundler -v
```

#### Установка mongoDB

```shell
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927
sudo bash -c 'echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.2.list'
sudo apt update
sudo apt install -y mongodb-org
```

Запускаем монгу и добавляем в автозагрузку

```shell
sudo systemctl start mongod
sudo systemctl enable mongod
```

#### Установка приложения

В домашней директории пользователя на машине reddit-app выполним:

```shell
git clone -b monolith https://github.com/express42/reddit.git
cd reddit && bundle install
```

Запускаем проект и проверяем, что он работает:

```shell
puma -d
ps aux | grep puma
```

### Создание startup script (*)
Необходимо закоммитить скрипт startup_script.sh в репозиторий, после чего воспользоваться параметром `--metadata startup-script-url` для скачивания и выполнения скрипта.
Этот скрипт всегда будет выполняться от пользователя **root**

Можно использовать параметр `--metadata startup-script`, но тогда придется указывать весь скрипт в командной строке. Это подходит только для небольших скриптов.

```shell
gcloud compute instances create reddit-app\
  --boot-disk-size=10GB \
  --image-family ubuntu-1604-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=g1-small \
  --tags puma-server \
  --restart-on-failure \
  --metadata startup-script-url='https://raw.githubusercontent.com/otus-devops-2019-05/SJay3_infra/cloud-testapp/startup_script.sh'
```

### Создание правила фаервола с помощью gcloud (*)

```shell
gcloud compute firewall-rules create default-puma-server --allow tcp:9292 --direction INGRESS --source-ranges="0.0.0.0/0" --target-tags puma-server
```


----
## Homework 3 (cloud-bastion)
В данном домашнем задании было сделано:
- Создание учетной записи в GCP
- Создание ssh ключей для инстансов ВМ
- Создание инстансов ВМ из веб-интерфейса
- Подключение по ssh через бастион-хост
- Подклчюение по vpn через бастион-хост
- Настройка ssl сертификатов для vpn-сервера

### Реквизиты ВМ

    bastion_IP = 35.228.209.11
    someinternalhost_IP = 10.166.0.5

### Регистрация учетной записи в GCP
Регистрация производится по ссылке: https://cloud.google.com/free/
Лучше всего использовать отдельный аккаунт Gmail.
Так же, в GCP был создан проект **infra**

### Создание ssh ключей и добавление их в GCP
#### для Windows
Можно сгенерировать ключи с помощью puttygen

#### для Linux
Генерируем ключ для пользователя *dusachev*

```shell
ssh-keygen -t rsa -f ~/.ssh/dusachev -C dusachev -P ""
```
#### добавление ключей в GCP
Заходим в Compute Engine -> Metadata -> SSH Keys.
Добавляем туда публичные ключи

### Подключение по ssh
#### Подключение с нестандартным ключем:
`ssh -i <path_to_key> <username>@<host>`
#### Настройка форвардинга ssh
Настраиваем формаврдинг с локальной машины.
Сначала запустим ssh-агент `eval "$(ssh-agent)"`
Теперь добаваил ключ в агент: `ssh-add ~/.ssh/dusachev`
#### Подключение через бастион-хост одной командой
Принцип следующий: Мы подключаемся через proxycommand к бастиону (35.228.209.11), после чего, тот проксирует нас на целевой сервер someinternalhost (10.166.0.5). Ключ `-W %h:%p` означает, что стандартный ввод и вывод будут форвардится на хост `%h` и порт `%p`. Эти переменные будут зарезолвены указаным хостом для подключения и портом.

```shell
ssh dusachev@10.166.0.5 -o "proxycommand ssh -W %h:%p -i ~/.ssh/dusachev dusachev@35.228.209.11"
```

#### Подключение через бастион-хост с использованием алиаса (*)
Для создания алиаса необходимо создать файл `~/.ssh/config` в котором прописать

``` shell
Host someinternalhost
  Hostname 10.166.0.5
  ForwardAgent yes
  User dusachev
  ProxyCommand ssh -W %h:%p -i ~/.ssh/dusachev dusachev@35.228.209.11

```

Или в случае, если версия openssh > 7.4, то можно использовать директиву ProxyJump. В таком случае конфиг будет выглядеть так:

```shell
Host someinternalhost
  Hostname 10.166.0.5
  ForwardAgent yes
  User dusachev
  ProxyJump dusachev@35.228.209.11
```

Теперь, что бы подключиться через бастион-хост нужно выполнить:

``` shell
ssh someinternalhost
```

### Подключение через VPN
#### Установка и первоначальная настройка VPN-сервера
Разрешим http/https трафик на машине bastion и установим vpn-server [Pritunl](https://pritunl.com/)

```shell
cat <<EOF> setupvpn.sh
#!/bin/bash
echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.4 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.4.list
echo "deb http://repo.pritunl.com/stable/apt xenial main" > /etc/apt/sources.list.d/pritunl.list
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 0C49F3730359A14518585931BC711F9BA15703C6
apt-key adv --keyserver hkp://keyserver.ubuntu.com --recv 7568D9BB55FF9E5287D586017AE645C0CF8E292A
apt-get --assume-yes update
apt-get --assume-yes upgrade
apt-get --assume-yes install pritunl mongodb-org
systemctl start pritunl mongod
systemctl enable pritunl mongod
EOF
```

Выполним созданный скрипт. В результате мы получим установленный сервер pritunl и базу mongodb

```shell
sudo bash setupvpn.sh
```

Для настройки vpn необходимо через браузер зайти на https://<bastion_address>/setup и выполнить инструкции на экране. Далее, необходимо:
 - залогиниться, добавить организацию, тестового пользователя, сервер. 
 - Добавить сервер в организацию. 
 - Создать правило файрвола в GCP для порта на котором запустился сервер.
 - Добавить тег правила в инстанс ВМ

Теперь необходимо установить openvpn-client на машину, с которой будет производиться подключение.
#### Установка и настройка openvpn клиента на рабочую машину
##### Для Ubuntu 18
Установим openvpn

```shell
    sudo apt update
    sudo apt install openvpn
```

Скачиваем с сервера файл `*.ovpn`. Для этого необходимо нажать на иконку с цепочкой у пользователя, профиль которого мы хотим скачать, копируем ссылку из первого окошка и выполняем:

```shell
wget https://35.228.209.11/key/AwBbkqSZvBaMUZ8hC5YtcR7i85MAyAG5.tar --no-check-certificate
tar -xvf AwBbkqSZvBaMUZ8hC5YtcR7i85MAyAG5.tar
```
В результате в текущей директории мы получим ovpn-файл.
Запускаем соединение с vpn-сервером:

```shell
sudo openvpn --config <path_to_ovpn_file>
```
Предложит ввести логин и пароль. Используем логин test и PIN в качестве пароля.
Если на экране появится строка `Initialization Sequence Completed` значит соединение успешно установлено.

#### Проверка работоспособности впн-сервера
Для проверки подключимся с рабочей машины к vpn-серверу и попробуем зайти по ssh на someinternalhost (Заходить нужно с другой консоли):

```shell
ssh -i ~/.ssh/dusachev dusachev@10.166.0.5
```

### Настройка сертификата для панели управления Pritunl (*)
Используемые сервисы:
- sslip.io
- Lets Encrypt

Для использования сервиса [sslip.io](https://sslip.io) достаточно обратиться к сервису с запросом по специальному dns-имени и он вернет в ответ ip-адрес. Работает это так: У нас есть внешний сервис на ip 35.228.209.11. Мы в браузере набираем 35-228-209-11.sslip.io и попадаем на веб-интерфейс нашего сервиса.

Для использования Lets Encrypt необходимо зайти в веб-интерфейс pritunl используя домен от sslip.io. Далее перейти в настройки и в поле Lets Encrypt Domain ввести адрес домена sslip.io.
После сохранения настроек страница обновится и подцепится валидный ssl-сертификат от Lets Encrypt

p.s. Возможно потребуется дополнительная установка certbot, который генерит сертификаты. Делается это следующим образом:

```shell
    sudo apt-get update
    sudo apt-get install software-properties-common
    sudo add-apt-repository universe
    sudo add-apt-repository ppa:certbot/certbot
    sudo apt-get update

    sudo apt-get install certbot 
```


----
## Homework 2 (play-travis)
В данном домашнем задании было сделано:
- Добавлен функционал использования Pull Request Template
- Интеграция Slack с github
- Интеграция Репозитория и Slack с travis

### Использование Pull Request Template
Pull Request Template - это технология github для шаблонизироания Pull Request'а (PR).
Для его использования, необходимо в корне проекта создать папку `.github`, в которую поместить шаблон с именем `PULL_REQUEST_TEMPLATE.md`

### Интеграция Slack с github
Для интеграции slack с github Для начала необходимо добавить приложение github в slack. [Инструкция](https://get.slack.help/hc/en-us/articles/232289568-GitHub-for-Slack)
Далее, создать канал в в slack (мой канал: #dmitriy_usachev), после чего выполнить команаду:

    /github subscribe Otus-DevOps-2019-05/SJay3_infra commits:all

### Интеграция репозитория и slack с travis
Для использования travis, необходимо в корень репозитория добавить файл `.travis.yml`, в котором описать инструкции по запуску сборки travis.
Для интеграции со slack необходимо добавить в slack приложение Travis CI, выбрать канал для уведомлений и сгенерировать токен.
Для обеспечения безопасности, данный токен необходимо зашифровать. Это можно сделать с помощью утилиты travis.
Инструкция по интеграции со slack (для Ubuntu 18.04):
1. Необходимо авторизоваться через github на сайте [travis](https://travis-ci.com)
2. Удаляем стандартый ruby из ubuntu, т.к. он немного кривой.

```shell
sudo apt-get remove ruby
```

3. Установим дополнительные пакеты

```shell
sudo apt install autoconf bison build-essential libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libncurses5-dev libffi-dev libgdbm5 libgdbm-dev
```

4. Установим rbenv

```shell
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
```

5. Проверим, что все установилось корректно

```shell
source ~/.bashrc
type rbenv
```
На экран выведется:

```shell
Output
rbenv is a function
rbenv ()
{
    local command;
    command="${1:-}";
    if [ "$#" -gt 0 ]; then
        shift;
    fi;
    case "$command" in
        rehash | shell)
            eval "$(rbenv "sh-$command" "$@")"
        ;;
        *)
            command rbenv "$command" "$@"
        ;;
    esac
}
```

6. Усстановим ruby-build plugin. Он необходим для использования команды `rbenv install`

```shell
git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
```

7. Выведем список того, что мы можем установить

```shell
rbenv install -l
```

8. Выберем необходимую версию руби (я выбрал 2.6.3), установим её, сделаем используемой по умолчанию и проверим, что версия установилась корректно

```shell
rbenv install 2.6.3
rbenv global 2.6.3
ruby -v
```

9. Устанавливать утилиту travis необходимо через gem (это утилита управления библиотеками и пакетами ruby). Для начала установим bundler, который необходим для управления зависимостями пакетов

```shell
gem install bundler
```

10. Теперь установим travis

```shell
gem install travis
```

11. Авторизуемся чезер утилиту travis

```shell
travis login --com
```

12. Теперь зашифруем токен с помощью утилиты travis. Мы должны находиться в папке с нашим репозиторием и в нем должен присутствовать файл `.travis.yml`

```shell
cd ~/otus/SJay3_infra
travis encrypt "devops-team-otus:<ваш_токен>#dmitriy_usachev" \
--add notifications.slack.rooms --com
```

13. travis автоматически добавит в файл `.travis.yml` шифрованый токен для уведомлений в slack. Остается только закоммитить изменения в файле.

### Самостоятельная работа (Добиться устпешного билда)
В файле `play-travis/test.py` была допущена ошибка в 6 строке.

```python
self.assertEqual(1 + 1, 1)
```
Эта функция всегда будет возвращать false по скольку, проверяем равнество 2-х чисел. В данном случае 2 не равно 1.
Необходимо исправить эту строку приведя её к виду:

```python
self.assertEqual(1, 1)
```
