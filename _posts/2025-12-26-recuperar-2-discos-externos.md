---
layout: post
title: "Recuperar 2 discos externos"
---

## Como usar 2 discos externos que estavam a apanhar pó?

Estava a arrumar algumas coisa e reparei em 2 discos externos que estavam a apanhar pó pelo menos desde 2021.

Após experimentar os discos e ver se que estavam ambos funcionais lembrei-me "se os discos estão aqui desligados porque não criar um file share com eles?"

Dai ter surgido a ideia de usar 2 discos como se fosse só um, tendo um único mount point dentro do servidor de SMB.

### Windows

![SMB Mount]({{ site.baseurl }}/assets/images/post-1/image.png)

![SMD Folders]({{ site.baseurl }}/assets/images/post-1/image2.png)

### Mac OS
![SMD Mount]({{ site.baseurl }}/assets/images/post-1/image3.png)

![SMD Folders]({{ site.baseurl }}/assets/images/post-1/image4.png)


Partilho o script usado para gerar estes setup:
```bash
#!/bin/bash

set -e

echo "====================================="
echo " SMB STORAGE SETUP (EXT4 + USERS)"
echo "====================================="

### CONFIGURAÇÃO
STORAGE="/mnt/storage"
SMB_GROUP="smbusers"

### LISTAR DISCOS DISPONÍVEIS
echo "[INFO] Discos disponíveis no sistema:"
echo "-----------------------------------"
lsblk -d -o NAME,SIZE,TYPE,MODEL | grep disk
echo "-----------------------------------"
echo

### SELEÇÃO DE DISCOS
declare -a SELECTED_DISKS
declare -a DISK_LABELS
echo "Selecione os discos que deseja usar (exemplo: sda, sdb, sdc)"
echo "Digite 'done' quando terminar"
echo

DISK_INDEX=1
while true; do
  read -p "Disco #$DISK_INDEX (ou 'done' para terminar): " DISK_INPUT
  
  [ "$DISK_INPUT" == "done" ] && break
  
  # Validar se o disco existe
  if [ -b "/dev/${DISK_INPUT}" ]; then
    SELECTED_DISKS+=("/dev/${DISK_INPUT}")
    DISK_LABELS+=("DISCO$DISK_INDEX")
    echo "✓ Adicionado: /dev/${DISK_INPUT}"
    ((DISK_INDEX++))
  else
    echo "✗ Disco /dev/${DISK_INPUT} não encontrado. Tente novamente."
  fi
done

# Verificar se pelo menos um disco foi selecionado
if [ ${#SELECTED_DISKS[@]} -eq 0 ]; then
  echo "Nenhum disco selecionado. Abortado."
  exit 1
fi

### CONFIRMAÇÃO
echo
echo "⚠️  AVISO: Os seguintes discos serão FORMATADOS:"
for i in "${!SELECTED_DISKS[@]}"; do
  echo "  - ${SELECTED_DISKS[$i]} (${DISK_LABELS[$i]})"
done
echo
read -p "Continuar? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Abortado."
  exit 1
fi

echo
echo "[1/8] Instalar dependências..."
apt update
apt install -y samba smartmontools e2fsprogs

echo "[2/8] Preparar e formatar discos..."
for i in "${!SELECTED_DISKS[@]}"; do
  DISK="${SELECTED_DISKS[$i]}"
  LABEL="${DISK_LABELS[$i]}"
  
  echo "  → Processando $DISK ($LABEL)..."
  
  # Desmontar se estiver montado
  umount "$DISK" 2>/dev/null || true
  
  # Formatar em ext4
  mkfs.ext4 -F -L "$LABEL" "$DISK"
done

echo "[3/8] Criar pontos de montagem..."
mkdir -p $STORAGE
for i in "${!SELECTED_DISKS[@]}"; do
  MOUNT_POINT="/mnt/usb$((i+1))"
  STORAGE_POINT="$STORAGE/disco$((i+1))"
  
  mkdir -p "$MOUNT_POINT"
  mkdir -p "$STORAGE_POINT"
done

echo "[4/8] Configurar /etc/fstab..."
cp /etc/fstab /etc/fstab.bak

echo "" >> /etc/fstab
echo "# SMB STORAGE SETUP - $(date)" >> /etc/fstab

for i in "${!SELECTED_DISKS[@]}"; do
  DISK="${SELECTED_DISKS[$i]}"
  UUID=$(blkid -s UUID -o value "$DISK")
  MOUNT_POINT="/mnt/usb$((i+1))"
  STORAGE_POINT="$STORAGE/disco$((i+1))"
  
  echo "  → Disco $DISK - UUID: $UUID"
  
  # Adicionar montagem do disco
  grep -q "$UUID" /etc/fstab || echo "UUID=$UUID  $MOUNT_POINT  ext4  defaults,nofail  0  2" >> /etc/fstab
  
  # Adicionar bind mount
  grep -q "$STORAGE_POINT" /etc/fstab || echo "$MOUNT_POINT  $STORAGE_POINT  none  bind,nofail  0  0" >> /etc/fstab
done

echo "[5/8] Montar todos os discos..."
mount -a

echo "[6/8] Criar grupo Samba..."
getent group $SMB_GROUP >/dev/null || groupadd $SMB_GROUP

echo "[7/8] Criar utilizador SMB..."
read -p "Nome do utilizador SMB: " USERNAME

if ! id "$USERNAME" &>/dev/null; then
  useradd -M -s /usr/sbin/nologin "$USERNAME"
  usermod -aG $SMB_GROUP "$USERNAME"
  echo "Definir password SMB para $USERNAME:"
  smbpasswd -a "$USERNAME"
  smbpasswd -e "$USERNAME"
else
  echo "Utilizador já existe. A atualizar password..."
  smbpasswd -a "$USERNAME"
fi

echo "[8/8] Configurar permissões e Samba..."
# Ajustar permissões (leitura e escrita para todos do grupo)
chown -R root:$SMB_GROUP $STORAGE
chmod -R 2775 $STORAGE

# Configurar Samba
cp /etc/samba/smb.conf /etc/samba/smb.conf.bak

grep -q "\[storage\]" /etc/samba/smb.conf || cat <<EOF >> /etc/samba/smb.conf

[global]
   server min protocol = SMB2
   map to guest = never

[storage]
   path = $STORAGE
   browseable = yes
   read only = no
   valid users = @$SMB_GROUP
   force group = $SMB_GROUP
   create mask = 0664
   directory mask = 2775
   comment = Shared Storage (${#SELECTED_DISKS[@]} discos)
EOF

# Reiniciar Samba
systemctl restart smbd
systemctl enable smbd

echo
echo "====================================="
echo " SETUP CONCLUÍDO COM SUCESSO"
echo "====================================="
echo "Discos configurados: ${#SELECTED_DISKS[@]}"
for i in "${!SELECTED_DISKS[@]}"; do
  echo "  - ${SELECTED_DISKS[$i]} → $STORAGE/disco$((i+1))"
done
echo
echo "Aceder via:"
echo "  Windows: \\\\IP_DO_SERVIDOR\\storage"
echo "  macOS:   smb://IP_DO_SERVIDOR/storage"
echo
echo "Utilizador SMB: $USERNAME"
echo
echo "Permissões: Leitura e Escrita para todos os utilizadores do grupo '$SMB_GROUP'"
echo
echo "Reboot recomendado."
```