import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Eight small PNG sprites faithfully derived from the owner's
/// traffic_signs.zip. Images have been resized to 64px and quantized for
/// compact source distribution; the original ZIP remains authoritative.
///
/// PNG sprites are compressed as zlib(JSON(base64(PNG))). No network requests,
/// native assets or changes to the user's SQLite data are required.
abstract final class TrafficSignIconPack {
  // Mapping is intentionally incomplete. Never map 50/51 until the owner
  // resolves which code means no stopping versus no parking.
  static const Map<int, String> iconKeyByType = {
    2: 'residential_area_start',
    3: 'residential_area_end',
    5: 'no_overtaking_start',
    6: 'no_overtaking_end',
    // Traffic light is only a provisional pictogram for type 32 ('đèn đỏ').
    32: 'traffic_light',
    36: 'no_car_right_turn',
    38: 'no_left_turn_and_uturn',
    40: 'no_left_turn',
  };

  static String? iconKey(int? typeCode) =>
      typeCode == null ? null : iconKeyByType[typeCode];

  static String? mapLibreImageId(int? typeCode) {
    final key = iconKey(typeCode);
    return key == null ? null : 'ttx-sign-icon-$key';
  }

  static final Map<String, String> _pngBase64 = () {
    final compressed = base64Decode(_packedArchive);
    final jsonBytes = zlib.decode(compressed);
    return (jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>)
        .map((key, value) => MapEntry(key, value as String));
  }();

  static Uint8List? pngForCode(int? typeCode) {
    final key = iconKey(typeCode);
    final encoded = key == null ? null : _pngBase64[key];
    return encoded == null ? null : base64Decode(encoded);
  }

  /// Registered after maritime protection has completed on every style load.
  static Iterable<(String, Uint8List)> get mapLibreImages sync* {
    for (final entry in iconKeyByType.entries) {
      final bytes = pngForCode(entry.key);
      final id = mapLibreImageId(entry.key);
      if (id != null && bytes != null) yield (id, bytes);
    }
  }

  static const String _packedArchive =
    'eNqlmVkPs1yWnf9L3xIJDNhApL44zPM835TAzPNkpij/PbxfpdOl7pISpbkA24JjDt7r2Wsd/49/WfK1zvJhq5Pub8mSJ39bt2TZ/uW//0vt04'
    'Z9IIpQjuDZdMerOK98XnF/3tKAAdpzZLINF9c/n0Q8rfmcDxcY9HnrQXFDMnXoGTdqb3+eF/2dYwMJkdCo03ABkwCYVDNrerls8QzDEL1vHvAL'
    'MhvUMau/CHg+U35fyNnJ/kSNMCOMMWufcwBgSbhAlo7S918WuU0mgQKj/Pl76vOWsotuBH/uRxJtx+00RtwJRAQmzBYkA7wCBvvKCtVIa4JvRj'
    'v+fA/8gktpgzsEV2/puVLQHM+mfbFJiKyYvqNWcoAuJzvVXunmdy2Gwhl01QgguUZSsjmCMW5gLpPvbKvvE9ZoUIl+lTr2G2ipiENcmEs9V1H/'
    '5USNSZzQK8W3G0JxxzpPL4pERed6OuOZwTRYx2xWgIyWngNba0a+4Sy6DiUxS+4PmABizCM9S3zJMAxGCD+aZUfu4CHAUQzD0xyNwJl2J4qVAW'
    'WlXTcCeeUDDo0YYplKfqVfuoMLv22tY4bBc8Dg4BcenfnyN8DsnPMuNICXxTGU2vf4uICxltoTAP3sHZxWc5Q7rOZ4f6QJzMxZR1+aG1o+q7o3'
    'rpcspttZW3Ega25TtBIgq9BJHxYPtAYtnzHPXftQc1Harxed32B8e4hQxt+SHpngXaVHex8C1OPIZy1krMxa7tBKZqrelhgJCM4SaqHRV+nVq7'
    'tYFo+x5cykAt6H7DYdA1ph2nGo/FHYG5JBnkIQTFFlWaqcx55wZJeB9qi83KKdyV1KN6qHjgZ7iC5mQ+3b7DuzCyp/XkKIrBx59c0UJuOnXg7G'
    'r/nxLpR925E/pQUczzds5c1EkvSv//Lf/rOG8iH7vyoIIH9XENBpDSf+XUFhLjpykrzLrqUEwxGKbJCxLhaMRWt74aezFaaf9rQJMZIHxUyMr2'
    'o5PkXqo/7QkUc2U/Idg/qZvO6J66mS33Zz/yhm6jYVBaVmNxokH1T2/lFu+Mk/wZXz7qwr++undoTxzldEkP9dQSb8bxv01375s8Phf9ggeP/7'
    'C6TWJPjPlfLwbwoa4mKL5vFgpXipInF8r0RwlqCmMCiUESzxKpDp5ucoDOtM3zPip362dGH4Ga6fL/6Y0NyxEf3wySpYUjxS1c8pWWh6ypCJMC'
    '/60ZgCi+5aHMEbNmSFMKZKK3WuIBTy5Ej2Mm9H10raNksYA1D1kmEKbbXtBVTipmBVTw4aPVC5/wUnSY0ymQMt6hFP+mjXcJMrpl4aIJQrw75m'
    'hU0q7e2fhVEYbGtlqZaeMu7Lnwa3+x8hoYiWePUPxGb6lCBDbMQ60RpDAM6FxsEPvisDzlsrL5DfbMxIUTl0LXxtTz19lgkjCXK73yjJ8fIFbb'
    'HfMAibHmu7oywUvCX8O/AV5EXmzlElb8kd5We7Dbvvmj4qAugSOdlWWNgEMtiyU4KzHIAABeqHsG2uRKCV9g9B0vRgy4qXIl4EdOxT0v3qVcwi'
    'YIhWxKdVIu99mL7FHbgN7mXSzOUgZ+uPwGjMkQ0NMMAXTCULWmw7pFaRvCbnFxp1eOP7AklN5le7gIhuq9NcQQRBbyO1uYBd4nEpuUL9XlkUYF'
    'pU2Sx9UZmlS5YBpPJg+3xsywYnZ18QdlREiW/HwTfOWBNeAiXGaI290AzONUu35MUowBjpQEdEqIhkjX9UepXULiaeFmpyJPQL4Fvi+nUf9cNo'
    't2uk64qCvrhgFQhIRmSEnqqI773UF6pelpSeab2z2VTOXvj8etOn2ampTtxvL0BF/0XV5F63+0DT+7kcgr8fm06YojnXIQasdcHkJQRZ0NS0Wz'
    'ws62YScp03iDsoDTmmC0xCJbE3uZqjMMSh6WxCZRSbaX/CL/aOlyxA7qUYzfuLKKBEt9aR/hllhvFv454vW9LWQ/lfbNNhJdcFCe3tn3bqhS8k'
    'FaqmHd5bGfEEyoBG01zhbbiFpDUqHPB1Pc40TB/54ncM4b1Cw2p+u8PaXRwEiN5WwGKx2aPNogz/tPsZ0l2H1BojGwIOFAcA8Gd8Wi3l+xbtz1'
    '3Icy4d/wNkKPhg/2III49GAlQYVCIMny0rmWQAH4YFHx4DDokFEBe38R8MK86/QWbyc3md15Ll0IpTmB+RotT12n/PcB0gnGRmSvJG7lQJNCNw'
    '2bbkSzotqt/AcsdRNRgjrMELgdlrP/oTZMb2TP+5gfO4NCZF8Uw26LUQGBHwHEIPcZmKZe/kbCzaN4BtCbVD4JqBC7QyKYlml8pZr1xgvZjSiL'
    'Wn4cueoPdU74rdqmGv6gbdnTof7ye97WSdashu02Pf6cJdI7f2T06LP1P5pS+ICN/9qmhbxFRFfcM9FNEulHAJj3OKcVdUtRkoXyuWyBLTnoSh'
    'zwi/E5Ee/yNS401XqWbuo0yV7qv5mKhM8ynNiruCC+s0KlHssy1X/0K7eF2xGfhHMeTrdailVbhj+2pmIHqVrHOegdBfDahQ12wgTBtW1IQOyK'
    'YNzku1VC/3xmh/d/TrFZAfvJtPgT4ivuUI/RQCrsN0nzmE4+hHPgwqZLTV76EE5RT18/a6DsNU2oap6jcvl0u7mqXGvSCa2aAPXKzkvm0nNccF'
    'BapwZ06D7kQ7q3Zon01/JQqIJGxm7LkGlu6ebsYB+WU0QStc4OyjarnvhsJ+Bi2IhfNb52KWXOFwjjVuFCuawNuWvU26EUkMyEY3JmS5tBdky5'
    '1x8WNpI4XHg/CTBENBonbCxhfmXlmaWoOAjNNrTz5JojS3vu1ejK7fyoEw5hzUJUF4aoMHfN35gyiWXgD5C16wb7rAhQvwuOReqlybz9NBv23X'
    'FiM1Riva2ESZkOcC8c2w3nFRVqXYWLB2xPqrP6BPAqaAQTAjTt116Kbh/ary94xaHz1jt1WPtgQfTkmjoAAXT58r80cq492WHiZz6M+W0zF32f'
    'VCg4IfUDPeKCafvsqN2kFewvGKbMoztgKNcAPBKd7tFX+dYsbAreG2T38HnBWI9mFXvvKXawFcx7ut87N6hvlPcPp/8j/w39FED8dN4P+OJm9o'
    'yfsg4b+w1U2JdzVpVoQo074MORyV0+wIDzfYEm1UeXxMkVEMlNalsdkt0esPDMLPc1SflIGRD3LIh/fc5QfPeCY5ZPIKCph6EgjVLL+A/VGMtX'
    '07K5eIF1X4zqDxK8S/P/+AJugPmqjHBnGmCg87yXYvsqeDiAHWkyb+pIqygQWT5Kauwg3jr6lG/4amxs/F76qVrOBJFswoEfpFPkUD75/7gSKf'
    '/+oYy8LSdL2tliYzLXkIXsyBKF/D/NsEGBIZ/J1kMb0V+Kr0euRbwNWxMggRQjJKG+4wMWKg/uzgV4RTZQXMlJvKcSt7BBIQDT19YFF4Spsv9Q'
    'NMPJHKwE8poTTeUykjVqKlrPIVwlwv1kl3i5w9KoiWVu+EyEWuzvrooVPNaVq4FfcWlem2JhtlIkZZ5jRWSMWajIlplF7TR78MGPvyaugjaAir'
    'iy4vqNSPk6Pmzu8u72rlQsZulHQJKSytxSpfLnXT5xA+TzSBykyyz7RfFZqnPCYrgOBa1dtzqZQqhylVfDMvIjdJwUekZXEE2sQucn+8sDqusr'
    'oym4/T5c4XpJy2wBd4vrxhkl6wtyLxBPiMscsMNYnv2cAA9zOyfVNyLsmIMR4UJSFcziGf7tERK3ylg0nXv8j9yDyw2/ZEVoS2KVzF6T5NZnDT'
    '5WUCEt2U+zZcppimacd1QaAz7+xf09NsD7j9+TgxmbI2lo9VdGnOAfh5fFOJ8SPSJVPSwU2wf/PSGuuOrN/QW1CGZ9SO5xtWttprM4nX0Qb8Wx'
    'qlTWD89xfflIy0jHf4FE8cxTqAaq36vgTbeY9f9FxwWk5suO2uAdSNtL/dNfDO0kf2uPHEAhvNmA77mRw+QcncVQUvQNVup3wbn2VQ51tkSbwr'
    'meSlUqvCJeXBDUe5T5B9U+uK7JrF98tlu9LTJdzi7eKpk01k7bMG1HpOiFaMk5GJedk8Y9F2KdqSxinbE5GXk2B8G+G/tT4Go3q6XlGFRxKRfZ'
    'EL+pD03eD1MRl+oPookj4E5Nzqg6fdRHpsJiuyWx/1o+HJp0kq4cSu8LLpJKdPN+Tal49BTAhFrCgKDZP7+aDZbACHaqO7NvfdV0iiDIN+JSZC'
    'TeB8XTg/QLOCLVHoK9wBz3Sb2QsPw7fyJc1Pj5IJvZhlLwqvoOGoXOF+T8i8+Kxdpw5t/cOoT1Z39nKCfSUU+M5vsi7xDmghjQM3emg0sLj4Cq'
    'g4UauqFKWgQsDF8l6Dq2A3Z33JkY0yxORldDiB75jdHlsafkegIOFBET00MOo7S2fGjVPjlaHvYzIxek5VfyqFT1ZkaUVKeOi2ed9v6+7EPTpg'
    'X6G62gfRFNfIRDKRPqT8E0RvS1IU9fdvXV1W///O8e8LMBRwU+ncd9bav6ld1BOdI5xlBrK9+7K9wBFgZt+y8HWt58mu9EU+BvHU3jOhPwGRdl'
    'WbxVnU3maMGUX7igI6L0MhurIxa8NqA9uKljvXN/BfC0Vk6qB2Hz8t+tten6/QHv+wwPMgvpXhneQihWPA/46kYCf5P0f6r3ek+GCah9GX3Hh/'
    'nKNw/p8FnjhVu1UqOc6h2b4sU8z7ZjYBw++MPehraHHC+ehy8jYahuoU//N4c4iYvueT61ZuoTqO1Dj61+m1TIDBKZ8c+LkBH6Tal0ZfBycdCr'
    'CfJjEcIOKCIy/FzOIjLylc681FEeuwr5w+WLRkJZAwbQN+Fs3zskALoHlcnQUQh1PtL30Ct+QTs3Vdmv2yYBZXubXFMuNoOvI83HZGF5CqQBp2'
    'w1MmF0ROwvSWdnAWIC4zP0/wucbb8o4nOB44ZBGOtorBkx25pSxenifUHDkIwD7Mes9xxGKZnVlpeegsRihxPhEzNmyIFeqqChCUAE6scCmfR7'
    '4EcXLwBPG9J162OE+Teq3vTkxsrelUZT5/W1U0+SaukmRnFCtwwsZazIfmreUiLedkdK9Gxkhr57ryvWP1qJTlLTULjfUDUblc89E4hr6XNu4n'
    'zuYpCQv5Fxnb/H4tcxQckGS9OsmGSuGFvnibnRjkxFLjV8SafbRTjty/zz6T24Z+zsQcDxfluIyeA8uPkECll5pw8neIU/AYORBdXLrCKyV3zM'
    'ypoxA2W+YHGJKxqzDPxLYgbdT783mHH/AWP1w9f41UWv+5G/omy9+WP0r72/Zbhv9vNxS6Wr1/KPiP7EArXcpLb8x8nD7ZEKOo136moKuK0MfE'
    'RHBu694feTGb6c6H224kTxuX4z2wcVM4FmxLtN9EjiW71dSlewU/w/Xh4mBu0xMlix36Y9mtUhwY/WYfNxQsClc3W53u/8kNFX9WbP8Etojmny'
    'f68Jt5Qlr6/L4MVfyRD85I5OXkevRnqvI/rAbF33k9WCnh20Jk+jFonWxxKQxWJdw8q67v+7oNmwI7HbIOaOHsCu9nFoSU2vNlL1pcfZ4sCPUZ'
    '8TQM4VVEYgRnj8dgIoGd6kshWUs0Ouqgmfs3f1rcHqmS7o+4KcyqNb7djNBpeTFWLjze9jIVekIZMgc52Ca+j4FP48PACmGF8rmFjUEI0d9PIh'
    '7gdRAQ6UJOxFZM5FLf8fz+tBwQRAQgM7MGPQ8M/eshS8e4Rpl+VCoQfhjq8Zz1q1OgMxciwt5wyY0WKAdkMQvsVPgacGSjpQAtw0PAEDgMzlRW'
    'lFSXaFmiuxm6CNQ1f93mWjLtJNhTv8DjJNnArYnlWHFGEOcQfuO1KOvj+ByGBsoTxKm6lSa6cAan12arKHEBdFzimacG8aiC6O6VFoeXsE0Oe8'
    'yp2AdU+o31O8TslAVQWsyPziOOd+tK3+poZzQOYbP3fJiMMPvs7wmw8SGuOFOrAnzfF2X7D38O5ElxnqBG1sMdWukLptp9N2qQogVprDKT87W4'
    'JnKQdji6T/OKgOKVs9aJj6Gjb+ik8ZBKhrnAxQtfAFGRWw9nR2t4AslQZVvwZOgLhSNv5yq2lgKWgw4muCGFlBlw+yyl8DaAaBmr2NDwcUUsBv'
    'fj8MnojOYH3SxZUg/kOl68A41d6TasX8TU5ZCEVvPTFfWpgErVGEW6RS5gEvrydzDFbGhiZbHKBGrzI6tC5BjYHnVMWKsRrZN+rbUkFTnZ+VIi'
    'Y2wkFjsuS9+L7Fp7dPHNxHKZsJAGnd36sWVGPop7ffipMka2v8Ksalc3BPbF2an4YyOnuGaZnsEIryP5oYdWFonF0kAzfwmp8DF0oDgGaSIZG/'
    'TXtBZm34L5SUXAz6N0CZ8hXiVrRcbBcTXNOoAOBawxfkfTlR9eFPsfE4xTbbuGVBbW0n6vNCCi6YtQ4wBt7tH+xuazU9irxpiEuvdALjJ61Ofv'
    '5xWysgPHFMbs6u8JLe0Lf0OR6ikvuEkr1EmHfX6NQZlNSF6DMoVglPwKBXWFHI0t3fsID4VarRu6OXj1jtvDtl/8m1MiGTZHcmL05/4wvfm5HL'
    'FDPf0baO7xSnDc4XtzZSHXVmkWeQcsAnQT4ysaMgxhFylV0VLP5hSDj9NQ9DZpTOT45zju8uLvJP5bMmR/+/3XmExC8F/nC7QVTnyV3ow1/MZE'
    'HHg7Hf0u2Zf5HQd804rV4wZK1gv5M+eqP9aHcTia+/Pf1hmjORKjCdbF/vyAtBYFdSlFwhjmETI9GgYiBe8EhG7bspkIu1os8YiDJYClhLeSQP'
    '+4Qg9M+MfAUPbH7CRAi+FDhYF1w0ypKfCxwI+mxb+c0C8iXP/PI1KPf2Dy8JqPkuUC1rJpBOqyHwVjBVkqtUzbLzckNKH9odUJyidXRZ1BPHHh'
    '5RggY6fkJn8uIbOmlD6dxEn4ooiNsmQHjgJmtV+6RGilzBAlLxA3sfeyWk2PRHhdNWgo9i6QgjrWcPGcFH08uC9bbIU2rxKjgIsvbsfXG6a0V+'
    'wDSzbibPAlBxXJ0ZMLz/tY+PmIbGB18bjAP0YAaQ0NGiba4TBHie6oXuFRH7TMfiLKoySl0jbLcqySHWFGXAVVjUU6BwL5Ip0RYMZ4WHRJWoGl'
    'fGWntIHwZsi+hRwYOCXnWdG7+Xwx8fhGjs38moqWRK2yrcYD3MfM8KbQubGUa8v9sVYY4bLzVYYaFzrQ3mH2pSSBjxYa4S+QSRIiIlCg28fHjW'
    '4LMRhuooVRe2bZhwbjY2GvjTJSHSRCra+jA1l52KrVN86HqExUsFPv4Zx1MtoGZcKXLjpFjc5Zcx08Gp6+8AsD4kqdvHbT9QgOGtCrdvKh/KMj'
    'YaIVwKRkdCvnABhNdDSSTgC3ningVJy0CXBqBYx1fvma3PevsUBvZDSIyh1jKyDj4ANaVvn0Y4+u8bsFtGxh3uZKSMlpTztPx2Q/N3oETPnBFR'
    'HneFR+3B5wZPqFRe1efy/qpbB38233K+8lHsjytvG3hFhIg0N1Ln9ROmq4g13EOYiB+JQX7zB37a/dO+M+QoZquziPv69DD5HPPC7oo42sNHIe'
    'feiqGWvSlcSHMf5kpwbc0xMFUPhwrrZjNHLVTvDCY171Ggq08ZyOugqUXAc4UX2WTZuuGVeiubGJ0Ai7LH7rfjxb0SvqXzYdT3nXW7qsUGEWJE'
    'bw9AlM4D8vrypKb8EuI5SxDMLUGM7rGlsT8WekPvTbkC2HERfrX8TTw97wjw8/QwP0ZQ/cu2mmGC2Ic4j2HiDFWXQNpA/10B5kbjOqi8Xbt3+c'
    '0SP94HH8Zgm34fJ5v41t69/87+NjTa+51ES+K8Ff1LRAjCYfLCIsvcx9DVR6Gm5HVVCgfhHzmsMg/ouOtGx7b25p5bIs//Vf/wMf/2tOlYT2Py'
    'cyj0uVRtlxv8P7ltPgye9ujXre52WwQe/5wstofIqx+np4E38CYeDz8leyYdj3A8RmF0Z3eSxGjcmzCL0c5l5rm/1ML8RswR96/qwGe5wrjUan'
    'BFksBWvIZQpCbfyHvxSwP9ATYChlBI2FjweCh0mNlqfC5wBTFj+C0oWZumBb6899q/c/OtV+1p5gGKvOkNS1y6sZApu7+QSUauIsOSbn6Ad9tM'
    'ck/cAuge+NmcR779sJiXtvVInNJNp3UaLiO5qtwNskwtshlIe8xOJ+WQXpLet/OT8ETcyK/HdED0d/os9FIRk4TIfK41JkRVKy+zH5spxmRLrR'
    '4A5GBC5lANeI5fScvG0wOZK1i68tr3rIVWIpRThOVzuL10hnQb/ra+ZddoLKC05rf8xwTT3SyMbO1nue0zgN4IyjhecZGIjbVsna70CSXrWpLi'
    '/SktbjMdF7yW+BmdmeOmS0il8fEPnsoc4MQR/OS6etdbeRF9AjmZe08gUUnLZD0Ir0zFUfdi1pHjYHFjqXxmlqvXA1sz5+ZVnFNdFlaa2KO4RL'
    'KubjqlvZX6o8pBv5khQu6BPyBLwyjEQPJDldulyfkZzaPAaweKCvlVSHA/EQnaVNpQzXWlIrEYSL8O51lQiRLCB8H4cBl+wWRBeu7AABBsko+C'
    'IfF+BJic3yoxo6hnUYNUYbipYCE/ftefpJ9ne0B3EFBtCnl2yTEJ1WgI58E8Sr+cZJ+h7zl3yTbGbay4ds+1IPf+J9YNerJp07YzifHU9O875R'
    'hYQfYnGseg7cUt3BMIYlvPAkWtglOZ4bo8fIheYcThw8PMd2IcDTjVuSliYhGQZPT3rSVlbbZ6LWl6g46krd40B1KG7NhvNBW++mTbKxqvC7cD'
    'vyMbvjt+ImGaKNVbftuBRnc1cEtCJem0lYm9Tllr2vShVO7yNbfHuvKmGM7htYwZ7gdLfoyddcNJvSQRjYPWN7oqbImSwZvCdLX3qZOLfzHctg'
    'PU3y9bkmP1B1K1aXhPKXOJ7HGdvze1JgGxn9HyvI/hpFR1CCMXb5vPpR4QZ70MTMmftbjVQ0Kq0es9g0GCJpvrv2oCGR2gJG6/whh+e55PTL+i'
    'huE6aOspAc3f515+h4n8mg9xOi5KF/tcvx0anxUM1XQHHyzfVU0U8veHPvVpy9zMigaCgw5J7NKbTzgYKpRXLMGU5sriv/CRn/5/8Cehwh8w==';
}
