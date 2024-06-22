import pymysql
mysql=None
class SQLdata():
    sql=None
    def __init__(self):
        self.sql=None

    def connect(self):
        try:
            self.sql = pymysql.Connect(host='localhost', port=3306, user='root', password='Yx030420',
                                       database='sql2024', charset='utf8')
        except Exception as e:
            print("Error:", e)
            self.sql = None  # 在连接失败时将 self.sql 设置为 None
        return self.sql
    def close(self):
        self.sql.close()
        self.sql=None
if(mysql==None):
    mysql=SQLdata()
def getMySql():
    return mysql
