# Okul bilgisayarında elle deneme listesi (sürüm 0.5.0)

Bu maddeler yalnız Windows'ta denenebilir; Mac'teki otomatik testler bunları
kapsamaz. Her maddenin yanına ✔ ya da sorunu yazın. Sorun çıkarsa
**Kayıtlar** sayfasının ekran görüntüsünü ve ayar klasöründeki
`hata_kayitlari.log` dosyasını saklayın.

Kurulum dosyası: GitHub → Actions → "Windows kurulum dosyası" → son başarılı
çalışma → **OkulZili-Kurulum** (içinde `OkulZili-Kurulum-0.5.0.exe`).

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

## 4. Pano modu
- [ ] 3 dk dokunulmayınca pano açılıyor (yazı alanında imleç ya da açık pencere yokken).
- [ ] Duyuru bandı akıyor, bugünün nöbetçileri görünüyor; projeksiyon/TV çözünürlüğünde yazılar taşmıyor.

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

## 7. Bildirim (PR #1 birleştirildikten sonra)
- [ ] Pencere gizliyken bir sorun olunca (ör. yüklenen ses dosyasını klasörden silip o zilin saatini bekleyin) Windows bildirimi geliyor.
- [ ] Bildirime tıklayınca Kayıtlar sayfası açılıyor.
- [ ] Bildirim gelmese bile tepsi ipucu "DİKKAT" yazıyor ve pencere odak çalmadan öne geliyor.

## 8. Android kumanda için ağ testi
- [ ] `tools/baglanti_testi.ps1` okul ağında çalıştırıldı; sonuç not edildi (telefon ve zil bilgisayarı aynı ağda birbirini görüyor mu).
