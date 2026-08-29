# powershell-DB
powershell-DB  ด้วย MAMP และ gemini cli



<img width="563" height="513" alt="image" src="https://github.com/user-attachments/assets/6a1ebd28-8a7f-4301-b2f4-2658b17a5830" />

1. ติดตั้ง จาก https://www.mamp.info/en/downloads/
2. ใช้ phpMyAdmin สำรวจและนำเข้าข้อมูล http://localhost/phpMyAdmin5/
3. Download "ecommerce_mamp_mysql57.sql" จาก git ด้านบน ซึ่งเป็นไฟล์ที่ปรับแก้โครงสร้างคำสั่งให้ทำงานกับ MAMP ได้อย่างถูกต้อง
4. นำเข้าด้วย import
   <img width="1135" height="601" alt="image" src="https://github.com/user-attachments/assets/4053b68c-9ba3-4970-b7c2-4e6ca9e2eef2" />

5. ตรวจสอบ MySQL ใน MAMP ก่อน  ด้วยคำสั่ง  :

   `netstat -ano | findstr :3306`

6. ทดสอบ MySQL ก่อนต่อ Gemini
- `& "C:\MAMP\bin\mysql\bin\mysql.exe" -h 127.0.0.1 -P 3306 -u root -proot`

- `SHOW DATABASES;`

- `USE ecommerce;`
- `SHOW TABLES;`

7. ตรวจสอบ Database ที่ต้องการ
- `USE ecommerce;`
- `SHOW TABLES;`

8. ตรวจสอบการติดตั้ง gemini cli   (https://geminicli.com/docs/get-started/installation/)
9. ติดตั้ง Gemini CLI MySQL Extension  Gemini CLI มี MySQL Extension อย่างเป็นทางการจาก gemini-cli-extensions/mysql ซึ่งทำงานผ่าน MCP และใช้ npx เป็นตัวรัน MCP serve
   - `gemini extensions install https://github.com/gemini-cli-extensions/mysql`

   กรณี PowerShell กำลังบล็อกไฟล์   (gemini.ps1 cannot be loaded) ให้ใช้คำสั่ง :
  - `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`

   แล้ว รัน อีกครั้ง `gemini extensions install https://github.com/gemini-cli-extensions/mysql`
   
