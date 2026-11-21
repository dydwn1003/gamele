import com.android.apksig.ApkSigner;
import com.android.apksig.ApkVerifier;
import java.io.*;
import java.security.*;
import java.security.cert.X509Certificate;
import java.util.*;

/** APK 서명 (v2 서명). 사용법: java SignApk <keystore> <storepass> <alias> <in.apk> <out.apk> */
public class SignApk {
  public static void main(String[] a) throws Exception {
    KeyStore ks = KeyStore.getInstance("PKCS12");
    try (InputStream in = new FileInputStream(a[0])) { ks.load(in, a[1].toCharArray()); }
    PrivateKey key = (PrivateKey) ks.getKey(a[2], a[1].toCharArray());
    X509Certificate cert = (X509Certificate) ks.getCertificate(a[2]);
    ApkSigner.SignerConfig sc = new ApkSigner.SignerConfig.Builder("EVERIN", key, Collections.singletonList(cert)).build();
    new ApkSigner.Builder(Collections.singletonList(sc))
        .setInputApk(new File(a[3])).setOutputApk(new File(a[4]))
        .setV1SigningEnabled(false).setV2SigningEnabled(true)
        .build().sign();
    ApkVerifier.Result r = new ApkVerifier.Builder(new File(a[4])).build().verify();
    System.out.println("signature verified=" + r.isVerified() + " (v2=" + r.isVerifiedUsingV2Scheme() + ")");
    for (Object e : r.getErrors()) System.out.println("ERR " + e);
    if (!r.isVerified()) System.exit(1);
  }
}
