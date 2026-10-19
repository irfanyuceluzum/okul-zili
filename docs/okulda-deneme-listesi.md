# Okul bilgisayarında elle deneme listesi (sürüm 0.6.0)

Bu maddeler yalnız Windows'ta denenebilir; Mac'teki otomatik testler bunları
kapsamaz. Her maddenin yanına ✔ ya da sorunu yazın. Sorun çıkarsa
**Kayıtlar** sayfasının ekran görüntüsünü ve ayar klasöründeki
`hata_kayitlari.log` dosyasını saklayın.

Kurulum dosyası: GitHub → Releases → **Okul Zili 0.6.0** →
`OkulZili-Kurulum-0.6.0.exe` (https://github.com/irfanyuceluzum/okul-zili/releases/tag/v0.6.0).

## 1. Kurulum ve güncelleme
- [ ] Önceki sürüm kuruluyken yeni kurulum dosyası açılınca çalışan Okul Zili kendiliğinden kapanıyor, kurulum hatasız bitiyor.
- [ ] Güncellemede "otomatik başlat" seçeneği önceki tercihle aynı geliyor (kapalıysa kapalı kalıyor).
- [ ] Güncellemeden sonra ders programı, tatiller, etkinlikler ve yüklenen sesler yerinde.
- [ ] Yüklenen sesler (Zil sesleri) dinlenebiliyor; çalınamıyorsa yerleşik zil çalıyor.

## 2. Açılış ve tepsi
- [ ] Bilgisayar yeniden başlayınca uygulama kendiliğinden açılıyor, pencere gösterilmeden tepside duruyor.
- [ ] Uygulama ikinci kez açılmak istenince yeni kopya açılmıyor, var olan pencere öne geliyor.
- [ ] Pencerenin çarpısı uygulamayı kapatmıyor, tepsiye gizliyor; ziller çalmaya devam ediyor.
- [ ] Tepsi simgesine tıklayınca pencere açılıyor; sağ tık menüsünde susturma ve çıkış çalışıyor.
- [ ] Çıkış onay istiyor.

## 3. Ziller ve ses
- [ ] Gerçek bir zil saatinde zil hoparlörden çalıyor (en az bir ders girişi, bir çıkış, bir öğretmen zili).
- [ ] Ayarlar'daki ses düzeyi Windows ses düzeyini değiştiriyor; Windows sessizdeyken zil saatinde ses açılıyor.
- [ ] Bilgisayar boşta kalınca uyku moduna geçmiyor (en az 1 ders saati bekleyin).
- [ ] Susturma süresi dolunca ziller yeniden çalıyor.
- [ ] Acil durum alarmı 2 sn basılı tutunca çalıyor, "Alarmı durdur" ile susuyor.
- [ ] Ders programında bir dersin süresini değiştirince sonraki dersler kayıyor; Kaydet'e basmadan eski program çalmaya devam ediyor.

## 3a. Ses paketi ve tören
- [ ] Yedi ses dosyası (İstiklal Marşı, saygı duruşu + İstiklal Marşı, zil sesleri) bir klasöre kondu; Zil sesleri → "Ses paketi yükle…" ile yüklendi, adlar doğru göründü.
- [ ] Her zil türü için istenen zil sesi seçildi ve dinlendi.
- [ ] Ana ekran → Tören → İstiklal Marşı hoparlörden sonuna kadar çalıyor; "Töreni durdur" kesiyor.
- [ ] Marş bir zil saatine denk gelince zil marşı kesmiyor, marş bitince çalıyor (Kayıtlar'da görünür).
- [ ] 10 Kasım etkinliği (Özel etkinlikler) saygı duruşu kaydını çalacak şekilde görünüyor; "Dinle" ile denendi.

## 3b. Zil sesleri ve anonslar
- [ ] Zil sesleri'nde bir sesin yanındaki oynat / duraklat / sürdür / durdur düğmeleri çalışıyor.
- [ ] Hazır bir ses (ör. Ding-dong) silinebiliyor; "Hazır sesleri geri getir" ile geri geliyor.
- [ ] Anonslar → "Yazıdan okut": Türkçe ses uyarısı çıkmıyor (çıkarsa Türkçe konuşma sesi yüklendi); "Dinle" anlaşılır Türkçe okuyor.
- [ ] Anonslar → "Mikrofondan kaydet": kayıt alınıyor, "Dinle" ile duyuluyor, kaydedilince listede görünüyor.
- [ ] Ana ekran → Anons: ding-dong + anons hoparlörden çalıyor; "Anonsu durdur" kesiyor.
- [ ] Özel etkinlik ses olarak bir anons seçilince saatinde kendiliğinden yapılıyor.

## 4. Pano modu
- [ ] 3 dk dokunulmayınca pano açılıyor (yazı alanında imleç ya da açık pencere yokken).
- [ ] Duyuru bandı akıyor, bugünün nöbetçileri görünüyor; projeksiyon/TV çözünürlüğünde yazılar taşmıyor.

## 4a. Pano: hava durumu, günün sözü, belirli günler
- [ ] Ayarlar → Pano modu → Hava durumu → "Konum seç…" ile okulun ilçesi bulundu ve seçildi.
- [ ] Panoda tarihin yanında sıcaklık ve durum görünüyor; internet kesilince bilgi saatiyle kalıyor, bağlantı gelince güncelleniyor.
- [ ] Panonun altında günün sözü görünüyor; belirli bir gün/hafta varsa "Bugün" bölümünde çıkıyor.
- [ ] Takvim → Belirli gün ve haftalar: istenmeyen günler kapatılabiliyor; Mevlid-i Nebî Haftası tarihi girilebiliyor.
- [ ] Pano gerçek ekranda (1366×768 ya da 1920×1080) taşmadan sığıyor.

## 5. Şifre kilidi (Ayarlar → Şifre kilidi)
- [ ] Şifre koyunca kurtarma kodu bir kez gösteriliyor (kâğıda yazın).
- [ ] Kilitle düğmesi ve pencereyi tepsiye gizlemek kilitliyor; ayar sayfaları şifre soruyor.
- [ ] Ana ekran ve pano şifresiz görünüyor; ziller kilitliyken de çalıyor.
- [ ] Kilit açıkken "Çıkış" şifre istiyor.
- [ ] Yanlış şifrede açılmıyor; kurtarma koduyla açılıyor. Şifre doğrulama birkaç saniyeden uzun sürmüyor.

## 6. Yedekler ve taşıma (Ayarlar → Yedekler ve taşıma)
- [ ] "Dışa aktar…" ile masaüstüne `.json` dosyası kaydediliyor (uzantı yazılmasa da ekleniyor).
- [ ] Başka bir ayarı değiştirip yedekten geri yükleyince eski hâl geliyor; "Geri al" çalışıyor.
- [ ] İçe aktarmada onay penceresi özet gösteriyor; şifre kilidi değişmiyor.

## 7. Windows bildirimi
- [ ] Pencere gizliyken bir sorun olunca (ör. yüklenen ses dosyasını klasörden silip o zilin saatini bekleyin) Windows bildirimi geliyor.
- [ ] Bildirime tıklayınca Kayıtlar sayfası açılıyor.
- [ ] Bildirim gelmese bile tepsi ipucu "DİKKAT" yazıyor ve pencere odak çalmadan öne geliyor.

## 8. Android kumanda için ağ testi
- [ ] `tools/baglanti_testi.ps1` okul ağında çalıştırıldı; sonuç not edildi (telefon ve zil bilgisayarı aynı ağda birbirini görüyor mu).
